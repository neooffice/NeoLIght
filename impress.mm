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

// impress.mm

// Process an OOo 1.1 formatted SXI impress file to extract metadata for spotlight
// indexing.  Will also function for draw files containing embedded text
// elements.

// Edward Peterlin
// 4/27/05

#include "impress.h"
#include "common.h"
#include <CoreServices/CoreServices.h>

///// constants /////

/**
 * Subfile in an SXI archive indicating the OOo metadata
 */
#define kImpressMetadataArchiveFile	"meta.xml"

/**
 * Subfile in an SXI archive holding the presentation content
 */
#define kImpressContentArchiveFile		"content.xml"

/**
 * Subfile in an SXI archive holding the style content
 */
#define kImpressStylesArchiveFile		"styles.xml"

///// prototypes /////

static void ParseImpressContentXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict);

///// functions /////

/**
 * Extract metadata from OOo Impress files.  This adds the OOo formatted metadata
 * as well as content of presentation nodes of the presentation.
 *
 * @param pathToFile	path to the sxi file that should be parsed.  It is
 *			assumed the caller has verified the type of this file.
 * @param spotlightDict	dictionary to be filled with Spotlight attributes
 *			for file metadata
 * @return noErr on success, else OS error code
 * @author ed
 */
OSErr ExtractImpressMetadata(CFStringRef pathToFile, CFMutableDictionaryRef spotlightDict)
{	
	// open the "meta.xml" file living within the sxi and read it into
	// the spotlight dictionary
	
	CFMutableDataRef metaCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	OSErr theErr=ExtractZipArchiveContent(pathToFile, kImpressMetadataArchiveFile, metaCFData);
	if(theErr!=noErr)
	{
		CFRelease(metaCFData);
		return(theErr);
	}
	ParseMetaXML(metaCFData, spotlightDict);
	CFRelease(metaCFData);
	
	// open the "content.xml" file within the sxi and extract its text
	
	CFMutableDataRef contentCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	theErr=ExtractZipArchiveContent(pathToFile, kImpressContentArchiveFile, contentCFData);
	if(theErr!=noErr)
	{
		CFRelease(contentCFData);
		return(theErr);
	}
	ParseImpressContentXML(contentCFData, spotlightDict);
	CFRelease(contentCFData);
	
	// open the "styles.xml" file and extract any header and footer
	
	CFMutableDataRef stylesCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	theErr=ExtractZipArchiveContent(pathToFile, kImpressContentArchiveFile, stylesCFData);
	if(theErr!=noErr)
	{
		CFRelease(stylesCFData);
		return(theErr);
	}
	ParseStylesXML(stylesCFData, spotlightDict);
	CFRelease(stylesCFData);

	return(noErr);
}

/**
 * Parse the content of a SXI file.  This places the content of outlines and
 * other text elements of the presentation into the CFText metadata item.
 *
 * @param contentCFData		XML file with content.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
static void ParseImpressContentXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict)
{
	if(CFDataGetLength(contentCFData)==0)
		return;
	
	// instantiate an XML parser on the content.xml file
	
	CFDictionaryRef errorDict=NULL;
	CFXMLTreeRef cfXMLTree=CFXMLTreeCreateFromDataWithError(kCFAllocatorDefault, contentCFData, NULL, kCFXMLParserReplacePhysicalEntities, kCFXMLNodeCurrentVersion, &errorDict);
	if(!cfXMLTree)
		return;
	if(errorDict)
	{
		// errors happened during our XML parsing.  Abort our interpretation and return.
		
		CFRelease(errorDict);
		return;
	}
	
	CFMutableDataRef textData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	
	// SXI files use elements of draw:text-box to hold all of its titles,
	// outlines, and other textual information.  Extract their text
	// content into the text content for spotlight indexing.
	
	ExtractNodeText(CFSTR("draw:text-box"), cfXMLTree, textData);
	
	// add the data as a text node for spotlight indexing
	
	CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(textData), CFDataGetLength(textData), kTextExtractionEncoding, false);
	if(CFDictionaryGetValue(spotlightDict, kMDItemTextContent))
	{
	    // append this text to the existing set
	    CFStringRef previousText=(CFStringRef)CFDictionaryGetValue(spotlightDict, kMDItemTextContent);
	    CFMutableStringRef newText=CFStringCreateMutable(kCFAllocatorDefault, 0);
	    CFStringAppend(newText, previousText);
	    UniChar space=' ';
	    CFStringAppendCharacters(newText, &space, 1);
	    CFStringAppend(newText, theText);
	    CFDictionaryReplaceValue(spotlightDict, kMDItemTextContent, newText);
	    CFRelease(newText);
	}
	else
	{
	    CFDictionaryAddValue(spotlightDict, kMDItemTextContent, theText);
	}
	CFRelease(theText);
	
	// cleanup and return
	
	CFRelease(textData);
	CFRelease(cfXMLTree);
}