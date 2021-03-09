//
//  WBOCTest.m
//  SwiftDemo
//
//  Created by 邓竹立 on 2021/2/26.
//

#import "WBOCTest.h"
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import "SwiftDefines.h"
#import "SwiftMethodTableModel.h"

@implementation WBOCTest

+ (void)load{
    NSLog(@"_mh_execute_header = %lu",((uintptr_t)&_mh_execute_header));
}

+ (void)replace:(id)obj0 methodIndex0:(int)mInx0 withClass:(id)obj1 methodIndex1:(int)mInx1{
    
    NSString *className0 = NSStringFromClass([obj0 class]);
    NSString *className1 = NSStringFromClass([obj1 class]);
    
    NSArray *methods0 = [self findMethodTable:className0].vTable;
    NSArray *methods1 = [self findMethodTable:className1].vTable;
    
    if (methods0.count >= mInx0 &&
        methods1.count >= mInx1) {
        
        uintptr_t imp0 = [methods0[mInx0] unsignedIntegerValue];
        uintptr_t imp1 = [methods1[mInx1] unsignedIntegerValue];
                
        struct SwiftClass* swiftClass = (__bridge struct SwiftClass * )obj0;
        
        UInt32 classObjectSize = swiftClass->classObjectSize;
        UInt32  classObjectAddressPoint = swiftClass->classObjectAddressPoint;
        
        int sizeOfVTable = (classObjectSize - classObjectAddressPoint) - 10 * sizeof(NSInteger);
        int totalVTableSize = sizeOfVTable / sizeof(NSInteger);
        
        for (int i = 0 ; i < totalVTableSize; i++) {
            uintptr_t tmp = (uintptr_t)swiftClass + (10 + i) * sizeof(NSInteger);
            uintptr_t funcAddress = (uintptr_t)*(void **)tmp;
            if (funcAddress == imp0) {
                memset((void*)tmp, 0, sizeof(NSInteger));
                memcpy((void*)tmp, &imp1, sizeof(NSInteger));
                break;
            }
        }
        return;
    }
}

+ (void)doReplace:(struct SwiftClass*)swiftClass oriIMP:(uintptr_t)oriIMP replace:(uintptr_t)replaceIMP{
    UInt32 classObjectSize = swiftClass->classObjectSize;
    UInt32  classObjectAddressPoint = swiftClass->classObjectAddressPoint;
    
    int sizeOfVTable = (classObjectSize - classObjectAddressPoint) - 10 * sizeof(NSInteger);
    int totalVTableSize = sizeOfVTable / sizeof(NSInteger);
    for (int i = 0 ; i < totalVTableSize; i++) {
        uintptr_t tmp = (uintptr_t)swiftClass + (10 + i) * sizeof(NSInteger);
        uintptr_t funcAddress = (uintptr_t)*(void **)tmp;
        if (funcAddress == oriIMP) {
            memset((void*)tmp, 0, sizeof(NSInteger));
            memcpy((void*)tmp, &replaceIMP, sizeof(NSInteger));
            break;
        }
    }
}

#warning 编译器能做哪些优化？优化对VTable是否有影响？
#warning 隐约记得在调研Mach-O时，有的相对地址计算完后很小，不能-linkbase，这里没有做容错，可能会有安全隐患
#warning 不同版本的Xcode 编译及不同的版本适配，是否会有问题？另外，能否适配__RODATA也没做验证
+ (void)replace:(id)class{
    const struct segment_command_64 *linkedit =  getsegbyname("__LINKEDIT");
    uintptr_t linkBase = linkedit->vmaddr-linkedit->fileoff;
    
    NSString *className = NSStringFromClass([class class]);
    NSArray *overrideTable = [self findMethodTable:className].overrideTable;
    struct SwiftClass* swiftClass = (__bridge struct SwiftClass * )class;
    for (SwiftOverrideMethodModel *overrideMethodModel in overrideTable) {
        id superclass = swiftClass->superclass;
        if (!superclass) {continue;}
        
        uintptr_t replaceIMP = overrideMethodModel.method;
        struct SwiftMethod *method = (struct SwiftMethod*)(overrideMethodModel.overrideMethod);
        uintptr_t oriIMP = (uintptr_t)method + sizeof(UInt32) + method->Offset - linkBase;
        //目前仅限实例方法生效
        #warning 编译器会自动生成一些函数，比如我继承了一个类，重写了2个函数，但是重写表中有3个函数，显然有一个不是我们需要的，能否精确识别出来这个函数？目前是通过函数的示例方法来限定的
        if (([self getSwiftMethodKind:method] == SwiftMethodKindMethod ||
             [self getSwiftMethodKind:method] == SwiftMethodKindModify)&&
            [self getSwiftMethodType:method] == SwiftMethodTypeInstance) {
            struct SwiftClass* targetClass = (__bridge struct SwiftClass*)superclass;
            [self doReplace:targetClass oriIMP:oriIMP replace:replaceIMP];
        }
    }
}

+ (SwiftMethodTableModel *)findMethodTable:(NSString *)class{
    
    SwiftMethodTableModel *methodTableModel = [SwiftMethodTableModel new];
    //获取__swift5_types 数据
    NSUInteger textTypesSize = 0;
    char *types = getsectdata("__TEXT", "__swift5_types", &textTypesSize);
    uintptr_t exeHeader = (uintptr_t)(&_mh_execute_header);
    const struct segment_command_64 *linkedit =  getsegbyname("__LINKEDIT");
    
    //计算linkBase
    uintptr_t linkBase = linkedit->vmaddr-linkedit->fileoff;
    
    NSUInteger location = 0;
    for (int i = 0; i < textTypesSize / sizeof(UInt32); i++) {
        
        uintptr_t offset = (uintptr_t)types + location - linkBase;
        location += sizeof(uint32_t);
        uintptr_t address = exeHeader + offset;
        UInt32 content = (UInt32)*(UInt32*)address;
        uintptr_t typeOffset = content + offset - linkBase;
        uintptr_t typeAddress = exeHeader + typeOffset;
        
        //不是类，则不处理
        struct SwiftType *type = (struct SwiftType *)typeAddress;
        if ((type->Flag & 0x1f) != SwiftKindClass ){
            continue;
        }
        
        NSMutableArray *vTable = @[].mutableCopy;
        NSMutableArray *ovTable = @[].mutableCopy;
        
        struct SwiftBaseType *baseType = (struct SwiftBaseType *)typeAddress;
        NSString *name = [self getTypeName:typeOffset];
        if (![class isEqualToString:name]) {
            continue;
        }
        //遍历Vtable和overrideTable
        BOOL hasVtable = [self hasVTable:baseType];
        BOOL hasOverrideTable = [self hasOverrideTable:baseType];
        BOOL hasSingletonMetadataInitialization = [self hasSingletonMetadataInitialization:baseType];
        BOOL hasResilientSuperclass = [self hasResilientSuperclass:baseType];
        short genericSize = [self addPlaceholderWithGeneric:typeOffset];
        if (!hasVtable && !hasOverrideTable ) {continue;}
        
        #warning typeLocation的计算在hasSingletonMetadataInitialization 和 有泛型的情况下可能会存在问题，因为我修改了SwiftClassTypeNoMethods 结构体，但是后面计算没有做适配修改（先跑通流程再处理）
        uintptr_t typeLocation = typeOffset + sizeof(struct SwiftClassTypeNoMethods) + genericSize + (hasResilientSuperclass?4:0)+ (hasSingletonMetadataInitialization?12:0) + (hasVtable?4:0) + exeHeader;
        
        if ([self hasVTable:baseType]) {
            UInt32* methodNum = (UInt32*)typeLocation;
            uintptr_t methodLocation = sizeof(UInt32);
            for (int j = 0; j < *methodNum; j ++) {
                uintptr_t methodAddress = typeLocation + methodLocation;
                struct SwiftMethod *methodType = (struct SwiftMethod *)methodAddress;
                if (methodType->Flag == 0x10) {
                    uintptr_t imp = ((long)methodType + sizeof(UInt32) + methodType->Offset - linkBase);
                    [vTable addObject:@(imp)];
                }
                methodLocation += sizeof(struct SwiftMethod);
            }
        }
        if ([self hasOverrideTable:baseType]) {
            UInt32* methodNum = (UInt32*)typeLocation;
            uintptr_t methodLocation = sizeof(UInt32);
            for (int j = 0; j < *methodNum; j ++) {
                uintptr_t methodAddress = typeLocation + methodLocation;
                struct SwiftOverrideMethod *methodType = (struct SwiftOverrideMethod *)methodAddress;
                SwiftOverrideMethodModel *model = [SwiftOverrideMethodModel new];
                uintptr_t overrideTypeAddress = (methodAddress + methodType->OverrideClass - linkBase);
                model.overrideClass = overrideTypeAddress;
                model.overrideMethod = (methodAddress + sizeof(UInt32) + methodType->OverrideMethod - linkBase);
                model.method = (methodAddress + 2 * sizeof(UInt32) + methodType->Method - linkBase);
                model.overrideClassName = [self getTypeName:(overrideTypeAddress - exeHeader)];
                [ovTable addObject:model];
                methodLocation += sizeof(struct SwiftOverrideMethod);
            }
        }
        
        methodTableModel.vTable = vTable.copy;
        methodTableModel.overrideTable = ovTable.copy;
        
    }
    return methodTableModel;
}

+ (NSString *)getTypeName:(uintptr_t)typeOffset {
    
    const struct segment_command_64 *linkedit =  getsegbyname("__LINKEDIT");
    //计算linkBase
    uintptr_t linkBase = linkedit->vmaddr-linkedit->fileoff;
    uintptr_t exeHeader = (uintptr_t)(&_mh_execute_header);
    uintptr_t typeAddress = exeHeader + typeOffset;
    
    //按SwiftType 结构去解析内存
    struct SwiftBaseType *baseType = (struct SwiftBaseType *)typeAddress;
    uintptr_t classNameOffset = typeOffset + baseType->Name + 8;
    char *className = (char *)(exeHeader + classNameOffset);
    NSString *name = [NSString stringWithFormat:@"%s",className];
    uintptr_t parentOffset = typeOffset + 1 * 4 + baseType->Parent - linkBase;
    SwiftKind kind = SwiftKindUnknown;
    while (kind != SwiftKindModule) {
        
        uintptr_t parent = exeHeader + parentOffset;
        
        struct SwiftBaseType *parentType = (struct SwiftBaseType *)parent;
        kind = parentType->Flag;
        
        uintptr_t parentNameContent = parentType->Name;
        uintptr_t parentNameOffset = parentOffset + 2 * 4 + parentNameContent;
        
        char *parentName = (char *)(exeHeader + parentNameOffset);
        name = [NSString stringWithFormat:@"%s.%@",parentName,name];
        
        uintptr_t parentOffsetContent = parentType->Parent - linkBase;
        parentOffset = parentOffset + 1 * 4 + parentOffsetContent;
    }
    
    return name;
}

#pragma mark Flag
+ (BOOL)hasVTable:(struct SwiftBaseType*)type{
    if ((type->Flag & 0x80000000) == 0x80000000) {return YES;}
    return NO;
}

+ (BOOL)hasOverrideTable:(struct SwiftBaseType*)type{
    if ((type->Flag & 0x40000000) == 0x40000000) {return YES;}
    return NO;
}

+ (BOOL)hasResilientSuperclass:(struct SwiftBaseType*)type{
    if ((type->Flag & 0x20000000) == 0x20000000) {return YES;}
    return NO;
}

+ (BOOL)isGenericType:(struct SwiftBaseType*)type{
    if ( (type->Flag & 0x80 )) {return YES;}
    return NO;
}

+ (BOOL)isGeneric:(struct SwiftType*)type{
    if ( (type->Flag & 0x80 )) {return YES;}
    return NO;
}

+ (BOOL)hasSingletonMetadataInitialization:(struct SwiftBaseType*)type{
    if ( (type->Flag & 0x00010000 )) {return YES;}
    return NO;
}

+ (SwiftMethodKind)getSwiftMethodKind:(struct SwiftMethod*)method{
    SwiftMethodKind kind = (SwiftMethodKind)(method->Flag&SwiftMethodTypeKind);
    return kind;
}

+ (SwiftMethodType)getSwiftMethodType:(struct SwiftMethod*)method{
    SwiftMethodType type = SwiftMethodTypeKind;
    if ((method->Flag&SwiftMethodTypeInstance) == SwiftMethodTypeInstance) {
        type = SwiftMethodTypeInstance;
    }else if ((method->Flag&SwiftMethodTypeDynamic) == SwiftMethodTypeDynamic){
        type = SwiftMethodTypeDynamic;
    }else if ((method->Flag&SwiftMethodTypeExtraDiscriminator) == SwiftMethodTypeExtraDiscriminator){
        type = SwiftMethodTypeExtraDiscriminator;
    }
    return type;
}

+ (SwiftKind)getSwiftType:(struct SwiftType*)type{
    //读低五位判断类型
    if ((type->Flag & 0x1f) == SwiftKindClass) {
        return SwiftKindClass;
    }else if ((type->Flag & 0x3) == SwiftKindProtocol){
        return SwiftKindProtocol;
    }else if((type->Flag & 0x1f) == SwiftKindStruct){
        return SwiftKindStruct;
    }else if((type->Flag & 0x1f) == SwiftKindEnum){
        return SwiftKindEnum;
    }else if((type->Flag & 0x0f) == SwiftKindModule){
        return SwiftKindModule;
    }
    
    return SwiftKindUnknown;
}

+ (short)addPlaceholderWithGeneric:(unsigned long long)typeOffset{
    
    struct SwiftType* swiftType = (struct SwiftType* )((uintptr_t)(&_mh_execute_header) + typeOffset);
    
    if (![self isGeneric:swiftType]) {
        return 0;
    }
    //非class 不处理
    if ([self getSwiftType:swiftType] != SwiftKindClass) {
        return 0;
    }
    
    short paramsCount = 0;
    short requeireCount = 0;
    void *p0 = (void *)((uintptr_t)(&_mh_execute_header) + typeOffset + 13 * 4);
    void *p1 = (void *)((uintptr_t)(&_mh_execute_header) + typeOffset + 13 * 4 + 2);
    
    memcpy(&paramsCount, p0, sizeof(short));
    memcpy(&paramsCount, p1, sizeof(short));
    
    //4字节对齐
    short pandding = (unsigned)-paramsCount & 3;
    
    /**
        
     16  =  4 + 4 + 2 + 2 + 2 + 2
     addMetadataInstantiationCache 4
     addMetadataInstantiationPattern 4
     GenericParamCount 2
     GenericRequirementCount 2
     GenericKeyArgumentCount 2
     GenericExtraArgumentCount 2
     */
    return (16 + paramsCount + pandding + 3 * 4 * (requeireCount) + 4);
}

@end
