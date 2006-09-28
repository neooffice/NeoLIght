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

// base.mm

// Process an OpenDocument database file to extract data for Spotlight
// indexing

// Edward Peterlin
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

static void ParseBaseContentXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict);

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
	// open the "meta.xml" file living within the sxc and read it into
	// the spotlight dictionary
	
	CFMutableDataRef metaCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	OSErr theErr=ExtractZipArchiveContent(pathToFile, kBaseMetadataArchiveFile, metaCFData);
	if(theErr==noErr)
	{
		ParseMetaXML(metaCFData, spotlightDict);
		CFRelease(metaCFData);
	}
	// note unlike other OpenDocument files, Base files seem to not consistently have a
	// meta document for them!  So let's continue to try to index regardless
	
	// open the "content.xml" file within the sxc and extract its text
	
	CFMutableDataRef contentCFData=CFDataCreateMutable(kCFAllocatorDefault, 0);
	theErr=ExtractZipArchiveContent(pathToFile, kBaseContentArchiveFile, contentCFData);
	if(theErr!=noErr)
	{
		CFRelease(contentCFData);
		return(theErr);
	}
	ParseBaseContentXML(contentCFData, spotlightDict);
	CFRelease(contentCFData);

	return(noErr);
}

/**
 * Parse the content of an odb file.
 *
 * @param contentCFData		XML file with content.xml extaction
 * @param spotlightDict		spotlight dictionary to be filled wih the text content
 */
static void ParseBaseContentXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict)
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
	
	// odb file content contains lists of table names and form names.  This information is stored in attributes
	// of the relevant nodes in the man content.xml file.
	
	// grab form names
	ExtractNodeAttributeValue(CFSTR("db:component"), CFSTR("db:name"), cfXMLTree, textData);
	
	// grab table names
	ExtractNodeAttributeValue(CFSTR("db:table"), CFSTR("db:name"), cfXMLTree, textData);
	
	// grab column names
	ExtractNodeAttributeValue(CFSTR("db:column"), CFSTR("db:name"), cfXMLTree, textData);
	
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