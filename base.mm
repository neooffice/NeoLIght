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

// base.mm

// Process an OpenDocument database file to extract data for Spotlight
// indexing

// Planamesa, Inc.
// 9/24/06

#include "base.h"
#include "common.h"
#include <CoreServices/CoreServices.h>

///// constants /////
/**
 * Subfile in an odb archive indicating the OOo metadata
 */
#define kBaseMetadataArchiveFile	"meta.xml"

/**
 * Subfile in an odb archive holding the table content
 */
#define kBaseContentArchiveFile		"content.xml"

///// prototypes /////

static void ParseBaseContentXML(NSData *contentNSData, CFMutableDictionaryRef spotlightDict);

///// functions /////

/**
 * Extract metadata from OOo Base files.  This adds the OOo formatted metadata
 * from the base file.
 *
 * @param pathToFile	path to the odb file that should be parsed.  It is
 *			assumed the caller has verified the type of this file.
 * @param spotlightDict	dictionary to be filled with Spotlight attributes
 *			for file metadata
 * @return noErr on success, else OS error code
 * @author ed
 */
OSErr ExtractBaseMetadata(CFStringRef pathToFile, CFMutableDictionaryRef spotlightDict)
{
    OSErr theErr = -50;
    
    if(!pathToFile || !spotlightDict)
        return(theErr);
        
	// open the "meta.xml" file living within the sxc and read it into
	// the spotlight dictionary
	
    NSMutableData *metaNSData=[NSMutableData dataWithCapacity:kFileUnzipCapacity];
	theErr=ExtractZipArchiveContent(pathToFile, kBaseMetadataArchiveFile, metaNSData);
	if(theErr==noErr)
		ParseMetaXML(metaNSData, spotlightDict);
    
	// note unlike other OpenDocument files, Base files seem to not consistently have a
	// meta document for them!  So let's continue to try to index regardless
    
	// open the "content.xml" file within the sxc and extract its text
	
	NSMutableData *contentNSData=[NSMutableData dataWithCapacity:kFileUnzipCapacity];
	theErr=ExtractZipArchiveContent(pathToFile, kBaseContentArchiveFile, contentNSData);
	if(theErr!=noErr)
		return(theErr);
	ParseBaseContentXML(contentNSData, spotlightDict);
    
	return(noErr);
}

/**
 * Parse the content of an odb file.
 *
 * @param contentNSData		XML file with content.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
static void ParseBaseContentXML(NSData *contentNSData, CFMutableDictionaryRef spotlightDict)
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
    
	// odb file content contains lists of table names and form names.  This information is stored in attributes
	// of the relevant nodes in the man content.xml file.
	
	// grab form names
	ExtractNodeAttributeValue(CFSTR("db:component"), CFSTR("db:name"), xmlTree, textData);
	
	// grab table names
	ExtractNodeAttributeValue(CFSTR("db:table"), CFSTR("db:name"), xmlTree, textData);
	
	// grab column names
	ExtractNodeAttributeValue(CFSTR("db:column"), CFSTR("db:name"), xmlTree, textData);
	
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
