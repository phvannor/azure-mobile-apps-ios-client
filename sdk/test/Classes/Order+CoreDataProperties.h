// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Order.h"

NS_ASSUME_NONNULL_BEGIN

@interface Order (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *id;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSManagedObject *customer;
@property (nullable, nonatomic, retain) NSSet<NSManagedObject *> *items;

@end

@interface Order (CoreDataGeneratedAccessors)

- (void)addItemsObject:(NSManagedObject *)value;
- (void)removeItemsObject:(NSManagedObject *)value;
- (void)addItems:(NSSet<NSManagedObject *> *)values;
- (void)removeItems:(NSSet<NSManagedObject *> *)values;

@end

NS_ASSUME_NONNULL_END
