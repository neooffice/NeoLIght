/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * This file is part of the LibreOffice project.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This file incorporates work covered by the following license notice:
 *
 *   Licensed to the Apache Software Foundation (ASF) under one or more
 *   contributor license agreements. See the NOTICE file distributed
 *   with this work for additional information regarding copyright
 *   ownership. The ASF licenses this file to you under the Apache
 *   License, Version 2.0 (the "License"); you may not use this file
 *   except in compliance with the License. You may obtain a copy of
 *   the License at http://www.apache.org/licenses/LICENSE-2.0 .
 */

// calc.mm

// Process an OOo 1.1 formatted SXC calc file to extract metadata for spotlight
// indexing.

// Planamesa, Inc.
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

/**
 * Subfile in an SXC archive holding the styles content
 */
#define kCalcContentStylesFile		"styles.xml"

///// prototypes /////

static void ParseCalcContentXML(NSData *contentNSData, CFMutableDictionaryRef spotlightDict);

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
    OSErr theErr = -50;
    
    if(!pathToFile || !spotlightDict)
        return(theErr);
    
	// open the "meta.xml" file living within the sxc and read it into
	// the spotlight dictionary
	
    NSMutableData *metaNSData=[NSMutableData dataWithCapacity:kFileUnzipCapacity];
    theErr=ExtractZipArchiveContent(pathToFile, kCalcMetadataArchiveFile, metaNSData);
    if(theErr!=noErr)
        return(theErr);
    ParseMetaXML(metaNSData, spotlightDict);
	
	// open the styles.xml file and read the header and footer info into
	// spotlight
	
    NSMutableData *stylesNSData=[NSMutableData dataWithCapacity:kFileUnzipCapacity];
	theErr=ExtractZipArchiveContent(pathToFile, kCalcContentStylesFile, stylesNSData);
	if(theErr!=noErr)
		return(theErr);
	ParseStylesXML(stylesNSData, spotlightDict);
	
	// open the "content.xml" file within the sxc and extract its text
	
    NSMutableData *contentNSData=[NSMutableData dataWithCapacity:kFileUnzipCapacity];
    theErr=ExtractZipArchiveContent(pathToFile, kCalcContentArchiveFile, contentNSData);
    if(theErr!=noErr)
        return(theErr);
    ParseCalcContentXML(contentNSData, spotlightDict);
    
	return(noErr);
}

/**
 * Parse the content of a SXC file.  This places the content of text cells
 * into a kMDItemTextContent node.
 *
 * @param contentNSData		XML file with content.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
static void ParseCalcContentXML(NSData *contentNSData, CFMutableDictionaryRef spotlightDict)
{
	if(!contentNSData || ![contentNSData length] || !spotlightDict)
		return;
	
	// instantiate an XML parser on the content.xml file
	
    NSXMLDocument *xmlTree = [[NSXMLDocument alloc] initWithData:contentNSData options:NSXMLNodeOptionsNone error:nil];
    if(!xmlTree)
        return;
    
    [xmlTree autorelease];
    
    NSMutableString *textData=[NSMutableString stringWithCapacity:kTextExtractionCapacity];
    if (!textData)
        return;
    
	// SXC files contain table:table-cell nodes that will have text:p
	// children giving either the text or the display form of the
	// value stored in the attributes of the table cell.  We'll run through
	// and extract the text children of all of the table-cell nodes to
	// allow searches on visible content.
	
	ExtractNodeText(CFSTR("table:table-cell"), xmlTree, textData);
	
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
