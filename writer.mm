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
 *         - GNU General Public License Version 2.1
 *
 *  Planamesa, Inc., 2005-2007
 *
 *  GNU General Public License Version 2.1
 *  =============================================
 *  Copyright 2005-2007 by Planamesa, Inc. (OPENSTEP@neooffice.org)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public
 *  License version 2.1, as published by the Free Software Foundation.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 *  MA  02111-1307  USA
 *
 ************************************************************************/

// writer.mm

// Contains implementation of code to parse OOo 1.x Writer formatted files
// and extract information into dictionaries for Spotlight indexing.

// Planamesa, Inc.
// 4/17/05

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include "writer.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "common.h"

static void ParseWriterContentXML(NSData *contentNSData, CFMutableDictionaryRef spotlightDict);

///// constants /////

/**
 * Subfile in an SXW archive indicating the content of a writer document
 */
#define kWriterContentArchiveFile	"content.xml"

/**
 * Subfile in an SXW archive indicating the metadata of a writer document
 */
#define kWriterMetadataArchiveFile	"meta.xml"

/**
 * Subfile in an SXW archive containing the style data of a writer document
 */
#define kWriterStyleArchiveFile		"styles.xml"

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
    OSErr theErr = -50;
    
    if(!pathToFile || !spotlightDict)
        return(theErr);
    
	// open the "content.xml" file living within the sxw and read it into
	// a NSData structure for use with other CoreFoundation elements.
	
	NSMutableData *contentNSData=[NSMutableData dataWithCapacity:kFileUnzipCapacity];
	theErr=ExtractZipArchiveContent(pathToFile, kWriterContentArchiveFile, contentNSData);
	if(theErr!=noErr)
		return(theErr);
	ParseWriterContentXML(contentNSData, spotlightDict);
	
	// open the "meta.xml" file living within the xsw and read it into
	// the spotlight dictionary
	
    NSMutableData *metaNSData=[NSMutableData dataWithCapacity:kFileUnzipCapacity];
	theErr=ExtractZipArchiveContent(pathToFile, kWriterMetadataArchiveFile, metaNSData);
	if(theErr!=noErr)
		return(theErr);
	ParseMetaXML(metaNSData, spotlightDict);
	
	// open the "styles.xml" file living within the sxw and read headers and
	// footers into the spotlight dictionary
	
    NSMutableData *styleNSData=[NSMutableData dataWithCapacity:kFileUnzipCapacity];
	theErr=ExtractZipArchiveContent(pathToFile, kWriterStyleArchiveFile, styleNSData);
	if(theErr!=noErr)
		return(theErr);
	ParseStylesXML(styleNSData, spotlightDict);
    
	return(noErr);
}

/**
 * Parse a content.xml file of an SXW into keys for spotlight.  This extracts the
 * data in text nodes into a kMDItemTextContent node that hopefully will
 * get indexed (seems to be nonfunctional)
 *
 * @param contentNSData		XML file with content.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
static void ParseWriterContentXML(NSData *contentNSData, CFMutableDictionaryRef spotlightDict)
{
	if(!contentNSData || ![contentNSData length] || !spotlightDict)
		return;
	
	// instantiate an XML parser on the content.xml file and extract
	// content of appropriate text nodes
	
    NSXMLDocument *xmlTree = [[NSXMLDocument alloc] initWithData:contentNSData options:NSXMLNodeOptionsNone error:nil];
    if(!xmlTree)
        return;
    
    [xmlTree autorelease];
    
    NSMutableString *textData=[NSMutableString stringWithCapacity:kTextExtractionCapacity];
    if (!textData)
        return;
    
	ExtractNodeText(CFSTR("text"), xmlTree, textData);
	
	// add the data as a text node for spotlight indexing
	
    if([textData length])
    {
        CFStringRef previousText=(CFStringRef)CFDictionaryGetValue(spotlightDict, kMDItemTextContent);
        if(previousText)
        {
            // append this text to the existing set
            if(CFStringGetLength(previousText))
            {
                [textData insertString:@" " atIndex:0];
                [textData insertString:(NSString *)previousText atIndex:0];
            }
            CFDictionaryReplaceValue(spotlightDict, kMDItemTextContent, (CFStringRef)textData);
        }
        else
        {
            CFDictionaryAddValue(spotlightDict, kMDItemTextContent, (CFStringRef)textData);
        }
	}
}
