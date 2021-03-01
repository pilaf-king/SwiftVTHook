//
//  SwiftDefines.h
//  SwiftDemo
//
//  Created by 邓竹立 on 2021/2/26.
//

#ifndef SwiftDefines_h
#define SwiftDefines_h

//    https://github.com/apple/swift/blob/e6af50198d49b006bf07c8c014242df7e29d39c9/include/swift/ABI/MetadataValues.h
typedef NS_ENUM(NSInteger, SwiftKind) {
    SwiftKindUnknown        = -1,    // UnKnown
    SwiftKindModule         = 0,     // Module
    SwiftKindProtocol       = 3,     // Protocol
    SwiftKindClass          = 16,    // Class
    SwiftKindStruct         = 17,    // Struct
    SwiftKindEnum           = 18     // Enum
};

struct SwiftType {
    uint32_t Flag;
    uint32_t Parent;
};

struct SwiftMethod {
    uint32_t Flag;
    uint32_t Offset;
};

struct SwiftBaseType {
    uint32_t Flag;
    uint32_t Parent;
    int32_t  Name;
    int32_t  AccessFunction;
    int32_t  FieldDescriptor;
};

struct SwiftClassType {
    uint32_t Flag;
    uint32_t Parent;
    int32_t  Name;
    int32_t  AccessFunction;
    int32_t  FieldDescriptor;
    int32_t  SuperclassType;
    uint32_t MetadataNegativeSizeInWords;
    uint32_t MetadataPositiveSizeInWords;
    uint32_t NumImmediateMembers;
    uint32_t NumFields;
    uint32_t Unknow1;
    uint32_t Offset;
    uint32_t NumMethods;
};

struct SwiftClass {
    NSInteger kind;
    id superclass;
    NSInteger reserveword1;
    NSInteger reserveword2;
    NSUInteger rodataPointer;
    UInt32 classFlags;
    UInt32 instanceAddressPoint;
    UInt32 instanceSize;
    UInt16 instanceAlignmentMask;
    UInt16 runtimeReservedField;
    UInt32 classObjectSize;
    UInt32 classObjectAddressPoint;
    NSInteger nominalTypeDescriptor;
    NSInteger ivarDestroyer;
    //----------------------------------
    //witnessTable[0]A
    //witnessTable[1]B
    //witnessTable[2]C
    //witnessTable[3]D
    //witnessTable[4]E
    //witnessTable[5]F
    //witnessTable[6]G
};


#endif /* SwiftDefines_h */
