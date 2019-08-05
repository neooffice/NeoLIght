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

//
//  main.c
//  neolight
//
//  Created by Planamesa, Inc. on 4/16/05.
//


#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include "writer.h"
#include "calc.h"
#include "impress.h"
#include "base.h"

// -----------------------------------------------------------------------------
//	constants
// -----------------------------------------------------------------------------

// Step 1. Generate a unique UUID for your importer
// 
// You can obtain a UUID by running uuidgen in Terminal.  The
// uuidgen program prints a string representation of a 128-bit
// number.
//
// Below, replace "MetadataImporter_PLUGIN_ID" with the string 
// printed by uuidgen.

#define PLUGIN_ID "8FC14E77-AE84-11D9-B35F-0003934F78AA"


// Step 2. Set the plugin ID in Info.plist
// 
// Replace the occurrances of MetadataImporter_PLUGIN_ID 
// in Info.plist with the string Representation of your GUUID

// Step 3. Set the UTI types the importer supports
//
// Modify the CFBundleDocumentTypes entry in Info.plist to contain
// an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
// that your importer can handle

// Optional:
// Step 4. If you are defining new attributes, update the schema.xml file
//
// Edit the schema.xml file to include the metadata keys that your importer returns.
// Add them to the <allattrs> and <displayattrs> elements.
//
// Add any custom types that your importer requires to the <attributes> element
//
// <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>

// Step 5. Implement the GetMetadataForFile function as requires by your document


// -----------------------------------------------------------------------------
//	Get metadata attributes from file
// 
// This function's job is to extract useful information your file format supports
// and return it as a dictionary
// -----------------------------------------------------------------------------

Boolean GetMetadataForFile(void *thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
    /* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
    
    short toReturn=FALSE;
    
    if (!attributes || !contentTypeUTI || !pathToFile)
        return(toReturn);
    
    if((CFStringCompare(contentTypeUTI, CFSTR("org.neooffice.writer"), 0)==kCFCompareEqualTo) ||
       (CFStringCompare(contentTypeUTI, CFSTR("org.oasis.opendocument.text"), 0)==kCFCompareEqualTo) ||
       (CFStringCompare(contentTypeUTI, CFSTR("org.oasis-open.opendocument.text"), 0)==kCFCompareEqualTo))
    {
        if(ExtractWriterMetadata( pathToFile, attributes )==noErr)
            toReturn=TRUE;
    }
    else if((CFStringCompare(contentTypeUTI, CFSTR("org.neooffice.calc"), 0)==kCFCompareEqualTo) ||
            (CFStringCompare(contentTypeUTI, CFSTR("org.oasis.opendocument.spreadsheet"), 0)==kCFCompareEqualTo) ||
            (CFStringCompare(contentTypeUTI, CFSTR("org.oasis-open.opendocument.spreadsheet"), 0)==kCFCompareEqualTo))
    {
        if(ExtractCalcMetadata( pathToFile, attributes )==noErr)
            toReturn=TRUE;
    }
    else if((CFStringCompare(contentTypeUTI, CFSTR("org.neooffice.impress"), 0)==kCFCompareEqualTo) ||
            (CFStringCompare(contentTypeUTI, CFSTR("org.oasis.opendocument.presentation"), 0)==kCFCompareEqualTo) ||
            (CFStringCompare(contentTypeUTI, CFSTR("org.oasis-open.opendocument.presentation"), 0)==kCFCompareEqualTo) ||
            (CFStringCompare(contentTypeUTI, CFSTR("org.neooffice.draw"), 0)==kCFCompareEqualTo) ||
            (CFStringCompare(contentTypeUTI, CFSTR("org.oasis.opendocument.graphics"), 0)==kCFCompareEqualTo) ||
            (CFStringCompare(contentTypeUTI, CFSTR("org.oasis-open.opendocument.graphics"), 0)==kCFCompareEqualTo))
    {
        if(ExtractImpressMetadata( pathToFile, attributes )==noErr)
            toReturn=TRUE;
    }
	else if((CFStringCompare(contentTypeUTI, CFSTR("org.oasis.opendocument.database"), 0)==kCFCompareEqualTo) ||
            (CFStringCompare(contentTypeUTI, CFSTR("org.oasis-open.opendocument.database"), 0)==kCFCompareEqualTo))
	{
        if(ExtractBaseMetadata( pathToFile, attributes )==noErr)
            toReturn=TRUE;
	}
    
    return(toReturn);
}


//
// Below is the generic glue code for all plug-ins.
//
// You should not have to modify this code aside from changing
// names if you decide to change the names defined in the Info.plist
//


// -----------------------------------------------------------------------------
//	typedefs
// -----------------------------------------------------------------------------

// The layout for an instance of MetaDataImporterPlugIn 
typedef struct __MetadataImporterPluginType
{
    MDImporterInterfaceStruct *conduitInterface;
    CFUUIDRef                 factoryID;
    UInt32                    refCount;
} MetadataImporterPluginType;

// -----------------------------------------------------------------------------
//	prototypes
// -----------------------------------------------------------------------------
//	Forward declaration for the IUnknown implementation.
//

extern "C"
{
MetadataImporterPluginType  *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID);
void                      DeallocMetadataImporterPluginType(MetadataImporterPluginType *thisInstance);
HRESULT                   MetadataImporterQueryInterface(void *thisInstance,REFIID iid,LPVOID *ppv);
void                     *MetadataImporterPluginFactory(CFAllocatorRef allocator,CFUUIDRef typeID);
ULONG                     MetadataImporterPluginAddRef(void *thisInstance);
ULONG                     MetadataImporterPluginRelease(void *thisInstance);
};
// -----------------------------------------------------------------------------
//	testInterfaceFtbl	definition
// -----------------------------------------------------------------------------
//	The TestInterface function table.
//

static MDImporterInterfaceStruct testInterfaceFtbl = {
    NULL,
    MetadataImporterQueryInterface,
    MetadataImporterPluginAddRef,
    MetadataImporterPluginRelease,
    GetMetadataForFile
};


// -----------------------------------------------------------------------------
//	AllocMetadataImporterPluginType
// -----------------------------------------------------------------------------
//	Utility function that allocates a new instance.
//      You can do some initial setup for the importer here if you wish
//      like allocating globals etc...
//
extern "C" MetadataImporterPluginType *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID)
{
    MetadataImporterPluginType *theNewInstance;

    theNewInstance = (MetadataImporterPluginType *)malloc(sizeof(MetadataImporterPluginType));
    memset(theNewInstance,0,sizeof(MetadataImporterPluginType));

        /* Point to the function table */
    theNewInstance->conduitInterface = &testInterfaceFtbl;

        /*  Retain and keep an open instance refcount for each factory. */
    theNewInstance->factoryID = ( CFUUIDRef )CFRetain(inFactoryID);
    CFPlugInAddInstanceForFactory(inFactoryID);

        /* This function returns the IUnknown interface so set the refCount to one. */
    theNewInstance->refCount = 1;
    return theNewInstance;
}

// -----------------------------------------------------------------------------
//	DeallocneolightMDImporterPluginType
// -----------------------------------------------------------------------------
//	Utility function that deallocates the instance when
//	the refCount goes to zero.
//      In the current implementation importer interfaces are never deallocated
//      but implement this as this might change in the future
//
extern "C" void DeallocMetadataImporterPluginType(MetadataImporterPluginType *thisInstance)
{
    CFUUIDRef theFactoryID;

    theFactoryID = thisInstance->factoryID;
    free(thisInstance);
    if (theFactoryID){
        CFPlugInRemoveInstanceForFactory(theFactoryID);
        CFRelease(theFactoryID);
    }
}

// -----------------------------------------------------------------------------
//	MetadataImporterQueryInterface
// -----------------------------------------------------------------------------
//	Implementation of the IUnknown QueryInterface function.
//
extern "C" HRESULT MetadataImporterQueryInterface(void *thisInstance,REFIID iid,LPVOID *ppv)
{
    CFUUIDRef interfaceID;

    interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault,iid);

    if (CFEqual(interfaceID,kMDImporterInterfaceID)){
            /* If the Right interface was requested, bump the ref count,
             * set the ppv parameter equal to the instance, and
             * return good status.
             */
        ((MetadataImporterPluginType*)thisInstance)->conduitInterface->AddRef(thisInstance);
        *ppv = thisInstance;
        CFRelease(interfaceID);
        return S_OK;
    }else{
        if (CFEqual(interfaceID,IUnknownUUID)){
                /* If the IUnknown interface was requested, same as above. */
            ((MetadataImporterPluginType*)thisInstance )->conduitInterface->AddRef(thisInstance);
            *ppv = thisInstance;
            CFRelease(interfaceID);
            return S_OK;
        }else{
                /* Requested interface unknown, bail with error. */
            *ppv = NULL;
            CFRelease(interfaceID);
            return E_NOINTERFACE;
        }
    }
}

// -----------------------------------------------------------------------------
//	MetadataImporterPluginAddRef
// -----------------------------------------------------------------------------
//	Implementation of reference counting for this type. Whenever an interface
//	is requested, bump the refCount for the instance. NOTE: returning the
//	refcount is a convention but is not required so don't rely on it.
//
extern "C" ULONG MetadataImporterPluginAddRef(void *thisInstance)
{
    ((MetadataImporterPluginType *)thisInstance )->refCount += 1;
    return ((MetadataImporterPluginType*) thisInstance)->refCount;
}

// -----------------------------------------------------------------------------
// SampleCMPluginRelease
// -----------------------------------------------------------------------------
//	When an interface is released, decrement the refCount.
//	If the refCount goes to zero, deallocate the instance.
//
extern "C" ULONG MetadataImporterPluginRelease(void *thisInstance)
{
    ((MetadataImporterPluginType*)thisInstance)->refCount -= 1;
    if (((MetadataImporterPluginType*)thisInstance)->refCount == 0){
        DeallocMetadataImporterPluginType((MetadataImporterPluginType*)thisInstance );
        return 0;
    }else{
        return ((MetadataImporterPluginType*) thisInstance )->refCount;
    }
}

// -----------------------------------------------------------------------------
//	neolightMDImporterPluginFactory
// -----------------------------------------------------------------------------
//	Implementation of the factory function for this type.
//
extern "C" void *MetadataImporterPluginFactory(CFAllocatorRef allocator,CFUUIDRef typeID)
{
    MetadataImporterPluginType *result;
    CFUUIDRef                 uuid;

        /* If correct type is being requested, allocate an
         * instance of TestType and return the IUnknown interface.
         */
    if (CFEqual(typeID,kMDImporterTypeID)){
        uuid = CFUUIDCreateFromString(kCFAllocatorDefault,CFSTR(PLUGIN_ID));
        result = AllocMetadataImporterPluginType(uuid);
        CFRelease(uuid);
        return result;
    }
        /* If the requested type is incorrect, return NULL. */
    return NULL;
}

