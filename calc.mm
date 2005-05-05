/*************************************************************************
 *
 *  $RCSfile$
 *
 *  $Revision$
 *
 *  last change: $Author$ $Date$
 *
 *  The Contents of this file are made available subject to the terms of
 *  either of the following licenses
 *
 *         - GNU Lesser General Public License Version 2.1
 *
 *  Edward Peterlin, 2005
 *
 *  GNU Lesser General Public License Version 2.1
 *  =============================================
 *  Copyright 2005 by Edward Peterlin (OPENSTEP@neooffice.org)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License version 2.1, as published by the Free Software Foundation.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 *  MA  02111-1307  USA
 *
 ************************************************************************/

// calc.mm

// Process an OOo 1.1 formatted SXC calc file to extract metadata for spotlight
// indexing.

// Edward Peterlin
// 4/27/05

#include "calc.h"
#include "common.h"
#include <CoreServices/CoreServices.h>

///// constants /////

/**
 * Subfile in an SXC archive indicating the OOo metadata
 */
#define kCalcMetadataArchiveFile	"meta.xml"

/**
 * Subfile in an SXC archive holding the table content
 */
#define kCalcContentArchiveFile		"content.xml"

///// prototypes /////

static void ParseCalcContentXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict);

///// functions /////

/**
 * Extract metadata from OOo Calc files.  This adds the OOo formatted metadata
 * as well as content of text cells in the spreadsheet.
 *
 * @param pathToFile	path to the sxc file that should be parsed.  It is
 *			assumed the caller has verified the type of this file.
 * @param spotlightDict	dictionary to be filled with Spotlight attributes
 *			for file metadata
 * @return noErr on success, else OS error code
 * @author ed
 */
OSErr ExtractCalcMetadata(CFStringRef pathToFile, CFMutableDictionaryRef spotlightDict)
{	
	// open the "meta.xml" file living within the sxc and read it into
	// the spotlight dictionary
	
	CFMutableDataRef metaCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	OSErr theErr=ExtractZipArchiveContent(pathToFile, kCalcMetadataArchiveFile, metaCFData);
	if(theErr!=noErr)
	{
		CFRelease(metaCFData);
		return(theErr);
	}
	ParseMetaXML(metaCFData, spotlightDict);
	CFRelease(metaCFData);
	
	// open the "content.xml" file within the sxc and extract its text
	
	CFMutableDataRef contentCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	theErr=ExtractZipArchiveContent(pathToFile, kCalcContentArchiveFile, contentCFData);
	if(theErr!=noErr)
	{
		CFRelease(contentCFData);
		return(theErr);
	}
	ParseCalcContentXML(contentCFData, spotlightDict);
	CFRelease(contentCFData);

	return(noErr);
}

/**
 * Parse the content of a SXC file.  This places the content of text cells
 * into a kMDItemTextContent node.
 *
 * @param contentCFData		XML file with content.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
static void ParseCalcContentXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict)
{
	// instantiate an XML parser on the content.xml file
	
	CFXMLTreeRef cfXMLTree=CFXMLTreeCreateFromData(kCFAllocatorDefault, contentCFData, NULL, kCFXMLParserReplacePhysicalEntities, kCFXMLNodeCurrentVersion);
	if(!cfXMLTree)
		return;
	
	CFMutableDataRef textData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	
	// SXC files contain table:table-cell nodes that will have text:p
	// children giving either the text or the display form of the
	// value stored in the attributes of the table cell.  We'll run through
	// and extract the text children of all of the table-cell nodes to
	// allow searches on visible content.
	
	ExtractNodeText(CFSTR("table:table-cell"), cfXMLTree, textData);
	
	// add the data as a text node for spotlight indexing
	
	CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(textData), CFDataGetLength(textData), kTextExtractionEncoding, false);
	CFDictionaryAddValue(spotlightDict, kMDItemTextContent, theText);
	CFRelease(theText);
	
	// cleanup and return
	
	CFRelease(textData);
	CFRelease(cfXMLTree);
}