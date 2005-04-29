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

// writer.mm

// Contains implementation of code to parse OOo 1.x Writer formatted files
// and extract information into dictionaries for Spotlight indexing.

// Edward Peterlin
// 4/17/05

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include "writer.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "common.h"

static void ParseContentXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict);

///// constants /////

/**
 * Subfile in an SXW archive indicating the content of a writer document
 */
#define kWriterContentArchiveFile	"content.xml"

/**
 * Subfile in an SXW archive indicating the metadata of a writer document
 */
#define kWriterMetadataArchiveFile	"meta.xml"

///// functions /////

/**
 * Extract metadata from OOo Writer files.  This adds the full text of the file
 * into the spotlight dictionary in order to allow for full text search on
 * writer files.
 *
 * @param pathToFile	path to the sxw file that should be parsed.  It is
 *			assumed the caller has verified the type of this file.
 * @param spotlightDict	dictionary to be filled with Spotlight attributes
 *			for file metadata
 * @return noErr on success, else OS error code
 * @author ed
 */
OSErr ExtractWriterMetadata(CFStringRef pathToFile, CFMutableDictionaryRef spotlightDict)
{
	// open the "content.xml" file living within the sxw and read it into
	// a CFData structure for use with other CoreFoundation elements.
	
	CFMutableDataRef contentCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	OSErr theErr=ExtractZipArchiveContent(pathToFile, kWriterContentArchiveFile, contentCFData);
	if(theErr!=noErr)
	{
		CFRelease(contentCFData);
		return(theErr);
	}
	ParseContentXML(contentCFData, spotlightDict);
	CFRelease(contentCFData);
	
	// open the "meta.xml" file living within the xsw and read it into
	// the spotlight dictionary
	
	CFMutableDataRef metaCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	theErr=ExtractZipArchiveContent(pathToFile, kWriterMetadataArchiveFile, metaCFData);
	if(theErr!=noErr)
	{
		CFRelease(metaCFData);
		return(theErr);
	}
	ParseMetaXML(metaCFData, spotlightDict);
	CFRelease(metaCFData);

	return(noErr);
}

/**
 * Parse a content.xml file of an SXW into keys for spotlight.  This extracts the
 * data in text nodes into a kMDItemTextContent node that hopefully will
 * get indexed (seems to be nonfunctional)
 *
 * @param contentCFData		XML file with content.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
static void ParseContentXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict)
{	
	// instantiate an XML parser on the content.xml file and extract
	// content of appropriate text nodes
	
	CFXMLTreeRef cfXMLTree=CFXMLTreeCreateFromData(kCFAllocatorDefault, contentCFData, NULL, kCFXMLParserReplacePhysicalEntities, kCFXMLNodeCurrentVersion);
	if(!cfXMLTree)
		return;
	
	CFMutableDataRef textData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	ExtractNodeText(CFSTR("text"), cfXMLTree, textData);
	
	// add the data as a text node for spotlight indexing
	
	CFStringRef theText=CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(textData), CFDataGetLength(textData), kCFStringEncodingUTF8, false);
	CFDictionaryAddValue(spotlightDict, kMDItemTextContent, theText);
	CFRelease(theText);
	
	// cleanup and return
	
	CFRelease(textData);
	CFRelease(cfXMLTree);
}