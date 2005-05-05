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

// common.h

// This file contains prototypes for functions to perform general purpose
// XML node text extraction and to process the shared meta.xml file format
// that is common to all OOo file types.

// Edward Peterlin
// 4/27/05

#ifndef COMMON_H_

#define COMMON_H_

#include <CoreFoundation/CoreFoundation.h>

/**
 * String encoding used for extracting text from OOo zip files
 */
#define kTextExtractionEncoding	    kCFStringEncodingUnicode

/**
 * Character type for the above string encoding
 */
typedef UInt16 TextExtractionCharType;

/**
 * Given a path to a zip archive, extract the content of an individual file
 * of that zip archive into a mutable data structure.
 *
 * The file is attempted to be extracted using UTF8 encoding.
 *
 * @param pathToArhive		path to the zip archive on disk
 * @param fileToExtract		file from the archive that should be extracted
 * @param fileContents		mutable data that should be filled with the
 *				contents of that subfile.    File content
 *				will be appended onto any preexisting data
 *				already in the ref.
 * @return noErr on success, else OS error code
 */
OSErr ExtractZipArchiveContent(CFStringRef pathToArchive, const char *fileToExtract, CFMutableDataRef fileContents);

/**
 * Given the content of a meta.xml document stored in a CFData object, extract
 * relevant metadata into a spotlight dictionary.
 */
void ParseMetaXML(CFMutableDataRef contentCFData, CFMutableDictionaryRef spotlightDict);

/**
 * Given a node of a CoreFoundation XML structure, extracxt any
 * text content from that node or recurse on the node's children as
 * appropriate.
 *
 * The text data is attempted to be extracted with UTF8 encoding, in
 * internal representation (no byte ordering marker)
 *
 * @param elementPrefix	element tag names are examined for this prefix.  When
 *			encountered, all text data child nodes will have their
 *			content concatenated onto the mutable data
 * @param xmlTreeNode	current tree representation of the node being parsed
 * @param textData	when the first element is found with the given prefix,
 *			all of the child text nodes of that element will
 *			have their content appended onto this mutable data
 *			elemnet.
 * @param separatorChar	UTF8 character used to separate consecutive text nodes in
 *			the metadata
 * @param saveText	true to save CFDATA node content as text, FALSE to just
 *			recurse into element children
 */
void ExtractNodeText(CFStringRef elementPrefix, CFXMLTreeRef xmlTreeNode, CFMutableDataRef textData, TextExtractionCharType separatorChar=' ', bool nodeEncountered=false);

#endif