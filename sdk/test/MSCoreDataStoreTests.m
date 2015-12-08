// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSCoreDataStore.h"
#import "MSCoreDataStore+TestHelper.h"
#import "MSJSONSerializer.h"
#import "TodoItem.h"
#import "Customer+CoreDataProperties.h"
#import "Item+CoreDataProperties.h"
#import "Order+CoreDataProperties.h"

@interface MSCoreDataStoreTests : XCTestCase {
    BOOL done;
}

@property (nonatomic, strong) MSCoreDataStore *store;
@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) MSClient *client;

@end

@implementation MSCoreDataStoreTests

// Table used for running tests
static NSString *const TableName = @"TodoItem";

- (void)setUp
{
    NSLog(@"%@ setUp", self.name);
    
    self.context = [MSCoreDataStore inMemoryManagedObjectContext];
    self.store = [[MSCoreDataStore alloc] initWithManagedObjectContext:self.context];
    self.client = [MSClient clientWithApplicationURLString:@""];
    self.client.syncContext = [[MSSyncContext alloc] initWithDelegate:nil dataSource:self.store callback:nil];
    
    XCTAssertNotNil(self.store, @"In memory store could not be created");
    
    done = NO;
}

-(void)tearDown
{
    self.store = nil;
    NSLog(@"%@ tearDown", self.name);

    [super tearDown];
}

-(void)testInit
{
    XCTAssertNotNil(self.store, @"store creation failed");
}

// Tests MSCoreDataStore Read, Update and Delete operations are case insensitive for the Id column.
-(void)testReadUpdateDelete_CaseInsensitiveIdOperations
{
    NSError *error;

    // Seed data to be inserted in the table
    NSString *originalItemId = @"itemid";
    NSArray *originalItems = @[ @{ @"id" : originalItemId, @"text" : @"original text" } ];

    // Data to be used for updating the table. The Id differs from the Id of the seed data only in case
    NSString *updatedItemId = @"ITEMID";
    NSString *updatedText = @"updated text";
    NSArray *updatedItems = @[ @{ @"id" : updatedItemId, @"text" : updatedText } ];
    
    // Initialize table
    MSSyncTable *syncTable = [[MSSyncTable alloc] initWithName:TableName client:self.client];

    // Populate the table
    [self.store upsertItems:originalItems table:TableName orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);

    // Read the table using ID with different case
    NSDictionary *item = [self.store readTable:TableName withItemId:updatedItemId orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(item, @"item should have been found in the table");

    // Update the item using ID with different case
    [self.store upsertItems:updatedItems table:TableName orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);

    // Verify the original row got updated
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:syncTable predicate:nil];
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertEqual(result.items.count, 1, @"Expected exactly one item in the table");
    XCTAssertTrue([result.items[0][@"id"] isEqualToString:updatedItemId], @"Incorrect item id. Did the query return wrong item?");
    XCTAssertTrue([result.items[0][@"text"] isEqualToString:updatedText], @"Incorrect text. Did the query return wrong item?");

    // Delete the row using an ID with different case
    [self.store deleteItemsWithIds:@[originalItemId] table:TableName orError:&error];
    XCTAssertNil(error, @"deleteItemsWithIds: failed: %@", error.description);

    // Read to ensure the item is actually gone
    result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertEqual(result.items.count, 0, @"Expected the table to be empty");
}

-(void)testUpsertSingleRecordAndReadSuccess
{
    NSError *error;
    NSArray *testArray = @[ @{ @"id":@"ABC", @"text": @"test1", @"version":@"APPLE" } ];
    
    [self.store upsertItems:testArray table:TableName orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:TableName withItemId:@"ABC" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(item, @"item should not have been nil");
    XCTAssertTrue([item[@"id"] isEqualToString:@"ABC"], @"Incorrect item id");
    XCTAssertNotNil(item[MSSystemColumnVersion], @"version was missing");
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertEqual(result.items.count, 1);
    
    item = (result.items)[0];
    XCTAssertNotNil(item);
    XCTAssertEqualObjects(item[@"id"], @"ABC");
    XCTAssertNotNil(item[MSSystemColumnVersion]);
}

-(void)testUpsertMultipleRecordsAndReadSuccess
{
    NSError *error;
    NSArray *testArray = @[@{@"id":@"A", @"text": @"test1"},
                            @{@"id":@"B", @"text": @"test2"},
                            @{@"id":@"C", @"text": @"test3"}];
    
    [self.store upsertItems:testArray table:TableName orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:TableName withItemId:@"B" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(item);
    XCTAssertEqualObjects(item[@"id"], @"B");
    XCTAssertEqualObjects(item[@"text"], @"test2");
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertEqual(result.items.count, 3);
}

-(void)testUpsertWithoutVersionAndReadSuccess
{
    NSError *error;
    NSArray *testArray = @[@{@"id":@"A", @"text": @"test1"}];
    
    [self.store upsertItems:testArray table:@"TodoNoVersion" orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:@"TodoNoVersion" withItemId:@"A" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(item, @"item should not have been nil");
    XCTAssertTrue([item[@"id"] isEqualToString:@"A"], @"Incorrect item id");
    XCTAssertNil(item[MSSystemColumnVersion]);
    XCTAssertNil(item[@"ms_version"]);
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:@"TodoNoVersion" client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result);
    XCTAssertEqual(result.items.count, 1);
    
    item = (result.items)[0];
    XCTAssertNotNil(item);
    XCTAssertEqualObjects(item[@"id"], @"A");
    XCTAssertNil(item[MSSystemColumnVersion]);
    XCTAssertNil(item[@"ms_version"]);
}

-(void)testUpsertSystemColumnsConvert_Success
{
    NSError *error;
    
    NSDate *now = [NSDate date];
    MSJSONSerializer *serializer = [MSJSONSerializer JSONSerializer];
    NSData *rawDate = [@"\"2014-05-27T20:37:33.055Z\"" dataUsingEncoding:NSUTF8StringEncoding];
    NSDate *testDate = [serializer itemFromData:rawDate withOriginalItem:nil ensureDictionary:NO orError:&error];
    
    NSDictionary *originalItem = @{
                               MSSystemColumnId:@"AmazingRecord1",
                               @"text": @"test1",
                               MSSystemColumnVersion: @"AAAAAAAAjlg=",
                               MSSystemColumnCreatedAt: testDate,
                               MSSystemColumnUpdatedAt: now,
                               @"meaningOfLife": @42,
                               MSSystemColumnDeleted : @NO
                           };
    
    [self.store upsertItems:@[originalItem] table:@"ManySystemColumns" orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    // Test read with id

    NSDictionary *item = [self.store readTable:@"ManySystemColumns" withItemId:@"AmazingRecord1" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    
    XCTAssertNotNil(item, @"item should not have been nil");
    XCTAssertTrue([item[MSSystemColumnId] isEqualToString:@"AmazingRecord1"], @"Incorrect item id");
    XCTAssertTrue([item[MSSystemColumnVersion] isEqualToString:originalItem[MSSystemColumnVersion]], @"Incorrect version");
    XCTAssertEqualObjects(item[MSSystemColumnUpdatedAt], originalItem[MSSystemColumnUpdatedAt], @"Incorrect updated at");
    XCTAssertEqualObjects(item[MSSystemColumnCreatedAt], originalItem[MSSystemColumnCreatedAt], @"Incorrect created at");
    XCTAssertEqualObjects(item[MSSystemColumnDeleted], originalItem[MSSystemColumnDeleted], @"Incorrect deleted");
    XCTAssertEqualObjects(item[@"meaningOfLife"], originalItem[@"meaningOfLife"], @"Incorrect meaning of life");
    
    NSSet *msKeys = [item keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        *stop = [(NSString *)key hasPrefix:@"ms_"];
        return *stop;
    }];
    XCTAssertTrue(msKeys.count == 0, @"ms_ column keys were exposed");
    
    // Repeat for query
    
    MSSyncTable *manySystemColumns = [[MSSyncTable alloc] initWithName:@"ManySystemColumns"
                                                                client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:manySystemColumns predicate:nil];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result);
    XCTAssertEqual(result.items.count, 1);
    
    XCTAssertNotNil(item, @"item should not have been nil");
    XCTAssertEqualObjects(item[MSSystemColumnId], @"AmazingRecord1");
    XCTAssertEqualObjects(item[MSSystemColumnVersion], originalItem[MSSystemColumnVersion]);
    XCTAssertEqualObjects(item[MSSystemColumnUpdatedAt], originalItem[MSSystemColumnUpdatedAt]);
    XCTAssertEqualObjects(item[MSSystemColumnCreatedAt], originalItem[MSSystemColumnCreatedAt]);
    XCTAssertEqualObjects(item[MSSystemColumnDeleted], originalItem[MSSystemColumnDeleted]);
    XCTAssertEqualObjects(item[@"meaningOfLife"], originalItem[@"meaningOfLife"]);
    
    msKeys = [item keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        *stop = [(NSString *)key hasPrefix:@"ms_"];
        return *stop;
    }];
    XCTAssertTrue(msKeys.count == 0, @"ms_ column keys were exposed");
}

-(void)testUpsertNoTableError
{
    NSError *error;
    NSArray *testArray = @[@{@"id":@"A", @"text": @"test1"}];
    
    [self.store upsertItems:testArray table:@"NoSuchTable" orError:&error];
    
    XCTAssertNotNil(error, @"upsert failed: %@", error.description);
    XCTAssertEqual(error.code, MSSyncTableLocalStoreError);
}


-(void)testUpsert_Relationships_InvalidChild_Error
{
    NSError *error;
    NSDictionary *originalItem = @{ @"id" : @"A", @"name" : @"test1", @"child" : @"123" };
    
    [self.store upsertItems:@[originalItem] table:@"Parent" orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:@"Parent" withItemId:@"A" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);

    XCTAssertEqual(item.count, 2);
    XCTAssertNil(item[@"child"]);
}

-(void)testUpsert_Relationships_NewRecords_Success
{
    NSError *error;
    
    [self populateDefaultParentChild];
    
    NSDictionary *item = [self.store readTable:@"Parent" withItemId:@"P_1" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(item, @"item should not have been nil");
    
    NSDictionary *childItem = [self.store readTable:@"Child" withItemId:@"C_1" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(childItem, @"item should not have been nil");
    
    // Verify core data state as well
    [self.context performBlockAndWait:^{
        NSManagedObject *parent = [self lookupRecordWithId:@"P_1" table:@"Parent"];
        XCTAssertNotNil(parent);
        
        NSArray *children = [parent objectIDsForRelationshipNamed:@"child"];
        XCTAssertEqual(children.count, 1);
    }];
}

-(void)testUpsert_Relationships_ExistingChildRecord_Success
{
    NSError *error;
    NSArray *testArray = @[
                           @{
                               @"id" : @"P_1",
                               @"name": @"ParentA",
                               @"child": @{
                                       @"id": @"C_1",
                                       @"value" : @14
                                       }
                               }
                           ];
    
    // Put a base child record into the store
    [self.store upsertItems:@[ @{ @"id": @"C_1", @"value" : @10 } ]
                      table:@"Child"
                    orError:&error];
    
    // Now insert a new Parent record
    [self.store upsertItems:testArray table:@"Parent" orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:@"Parent" withItemId:@"P_1" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(item, @"item should not have been nil");
    
    NSDictionary *childItem = [self.store readTable:@"Child" withItemId:@"C_1" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(childItem, @"item should not have been nil");
    
    // Verify value was changed correctly
    XCTAssertEqualObjects(childItem[@"value"], @14);
    
    // Verify core data state as well
    [self.context performBlockAndWait:^{
        NSManagedObject *parent = [self lookupRecordWithId:@"P_1" table:@"Parent"];
        XCTAssertNotNil(parent);
        
        NSArray *children = [parent objectIDsForRelationshipNamed:@"child"];
        XCTAssertEqual(children.count, 1);
    }];
}

-(void)testUpsert_Relationships_ExistingParentRecord_Success
{
    NSError *error;
    NSArray *testArray = @[ @{
        @"id" : @"P_1",
        @"child": @{ @"id": @"C_1", @"value" : @14 }
    } ];
    
    // Put the record we are updating into the store
    [self.store upsertItems:@[ @{ @"id": @"P_1", @"name" : @"ParentA" } ]
                      table:@"Parent"
                    orError:&error];
    
    // Now insert a new Parent record
    [self.store upsertItems:testArray table:@"Parent" orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:@"Parent" withItemId:@"P_1" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(item, @"item should not have been nil");
    XCTAssertTrue([item[@"id"] isEqualToString:@"P_1"], @"Incorrect item id");
    
    NSDictionary *childItem = [self.store readTable:@"Child" withItemId:@"C_1" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(childItem, @"item should not have been nil");
    
    // Verify core data state as well
    [self.context performBlockAndWait:^{
        NSManagedObject *parent = [self lookupRecordWithId:@"P_1" table:@"Parent"];
        XCTAssertNotNil(parent);
        
        NSArray *children = [parent objectIDsForRelationshipNamed:@"child"];
        XCTAssertEqual(children.count, 1);
    }];
}

-(void)testUpsert_Relationships_KeptIfPropertyNil_Success
{
    NSError *error;
    
    [self populateDefaultParentChild];
    
    // Update just the parent record
    [self.store upsertItems:@[ @{ @"id" : @"P_1", @"name": @"ParentB" } ]
                      table:@"Parent"
                    orError:&error];
    
    // Read actual object
    [self.context performBlockAndWait:^{
        NSManagedObject *parent = [self lookupRecordWithId:@"P_1" table:@"Parent"];
        XCTAssertNotNil(parent);
        
        NSArray *children = [parent objectIDsForRelationshipNamed:@"child"];
        XCTAssertTrue(children.count == 1);
        
        NSManagedObject *child = [self lookupRecordWithId:@"C_1" table:@"Child"];
        XCTAssertNotNil(child);
        
        children = [child objectIDsForRelationshipNamed:@"parent"];
        XCTAssertTrue(children.count == 1);
    }];
}

-(void)testUpsert_Relationships_RemoveExistingRelationship_Success
{
    NSError *error;
    [self populateDefaultParentChild];
    
    // Seperate the relationship now
    [self.store upsertItems:@[ @{ @"id" : @"P_1", @"child" : [NSNull null] } ]
                      table:@"Parent"
                    orError:&error];
    
    // Read actual object
    [self.context performBlockAndWait:^{
        NSManagedObject *parent = [self lookupRecordWithId:@"P_1" table:@"Parent"];
        XCTAssertNotNil(parent);
        
        NSArray *children = [parent objectIDsForRelationshipNamed:@"child"];
        XCTAssertNil(children);
        
        NSManagedObject *child = [self lookupRecordWithId:@"C_1" table:@"Child"];
        XCTAssertNotNil(child);
        
        children = [child objectIDsForRelationshipNamed:@"parent"];
        XCTAssertNil(children);
    }];
}

-(void)testUpsert_Relationships_ManyToMany_Success
{
    NSError *error;
    NSArray *testOrders = @[ @{
        @"id" : @"O-1",
        @"customer" : @{ @"id" : @"C-1", @"name" : @"Fred" },
        @"items" : @[
                @{ @"id" : @"I-1", @"name" : @"Phone" },
                @{ @"id" : @"I-2", @"name" : @"Laptop" },
                @{ @"id" : @"I-3", @"name" : @"Tablet" }
        ]
    }, @{
         @"id" : @"O-2",
         @"customer" : @{ @"id" : @"C-1", @"name" : @"Fred" },
         @"items" : @[
             @{ @"id" : @"I-1", @"name" : @"Phone" },
             @{ @"id" : @"I-4", @"name" : @"Keyboard" }
         ]
    }, @{
         @"id" : @"O-3",
         @"customer" : @{ @"id" : @"C-2", @"name" : @"George" },
         @"items" : @[
                 @{ @"id" : @"I-1", @"name" : @"Phone" },
                 @{ @"id" : @"I-3", @"name" : @"Tablet" },
             ]
     }  ];

    [self.store upsertItems:testOrders
                      table:@"Order"
                    orError:&error];
    
    // Verify all our records were created and relationships look good
    
    [self.context performBlockAndWait:^{
        // Check customers were created ok
        Customer *customer = (Customer *)[self lookupRecordWithId:@"C-1" table:@"Customer"];
        XCTAssertNotNil(customer);
        XCTAssertEqualObjects(customer.name, @"Fred");
        XCTAssertEqual(customer.orders.count, 2);
        
        customer = (Customer *)[self lookupRecordWithId:@"C-2" table:@"Customer"];
        XCTAssertNotNil(customer);
        XCTAssertEqualObjects(customer.name, @"George");
        XCTAssertEqual(customer.orders.count, 1);
        
        // Check items were created ok
        Item *item = (Item *)[self lookupRecordWithId:@"I-1" table:@"Item"];
        XCTAssertNotNil(item);
        XCTAssertEqualObjects(item.name, @"Phone");
        XCTAssertEqual(item.orders.count, 3);

        item = (Item *)[self lookupRecordWithId:@"I-2" table:@"Item"];
        XCTAssertNotNil(item);
        XCTAssertEqualObjects(item.name, @"Laptop");
        XCTAssertEqual(item.orders.count, 1);
        
        item = (Item *)[self lookupRecordWithId:@"I-3" table:@"Item"];
        XCTAssertNotNil(item);
        XCTAssertEqualObjects(item.name, @"Tablet");
        XCTAssertEqual(item.orders.count, 2);
        
        item = (Item *)[self lookupRecordWithId:@"I-4" table:@"Item"];
        XCTAssertNotNil(item);
        XCTAssertEqualObjects(item.name, @"Keyboard");
        XCTAssertEqual(item.orders.count, 1);
        
        Order *order = (Order *)[self lookupRecordWithId:@"O-1" table:@"Order"];
        XCTAssertNotNil(order);
        XCTAssertNotNil(order.customer);
        customer = (Customer *)order.customer;
        XCTAssertEqualObjects(customer.id, @"C-1");
        XCTAssertEqual(order.items.count, 3);

        order = (Order *)[self lookupRecordWithId:@"O-2" table:@"Order"];
        XCTAssertNotNil(order);
        XCTAssertNotNil(order.customer);
        customer = (Customer *)order.customer;
        XCTAssertEqualObjects(customer.id, @"C-1");
        XCTAssertEqual(order.items.count, 2);
        
        order = (Order *)[self lookupRecordWithId:@"O-3" table:@"Order"];
        XCTAssertNotNil(order);
        XCTAssertNotNil(order.customer);
        customer = (Customer *)order.customer;
        XCTAssertEqualObjects(customer.id, @"C-2");
        XCTAssertEqual(order.items.count, 2);
        
    }];
}

-(void)testReadTable_RecordWithNullPropertyValue
{
    NSError *error;
    NSArray *testArray = @[@{@"id":@"ABC", @"text": [NSNull null]}];
    
    [self.store upsertItems:testArray table:TableName orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:TableName withItemId:@"ABC" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    
    XCTAssertEqual(item[@"text"], [NSNull null], @"Incorrect text value. Should have been null");
}

-(void)testReadTable_RecordWithRelationships
{
    NSError *error;
    NSManagedObject *parent = [NSEntityDescription insertNewObjectForEntityForName:@"Parent"
                                                            inManagedObjectContext:self.context];
    NSManagedObject *child = [NSEntityDescription insertNewObjectForEntityForName:@"Child"
                                                            inManagedObjectContext:self.context];
    
    [parent setValue:@"A" forKey:@"id"];
    [parent setValue:@"TheParent" forKey:@"name"];
    [child setValue:@"A-1" forKey:@"id"];
    [child setValue:@12 forKey:@"value"];
    [parent setValue:child forKey:@"child"];
    
    if (![self.context save:&error]) {
        XCTFail(@"Failed to setup relationship data: %@", error.description);
    }
    
    NSDictionary *item = [self.store readTable:@"Parent" withItemId:@"A" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    
    XCTAssertEqualObjects(item[@"name"], @"TheParent");
    XCTAssertNil(item[@"child"]);
    
    item = [self.store readTable:@"Child" withItemId:@"A-1" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    
    XCTAssertEqualObjects(item[@"value"], @12);
    XCTAssertNil(item[@"parent"]);
    
    MSSyncTable *parentTable = [[MSSyncTable alloc] initWithName:@"Parent" client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:parentTable predicate:nil];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    
    XCTAssertNil(error, @"readWithQuery:orError failed: %@", error.description);
    item = result.items[0];
    XCTAssertEqualObjects(item[@"name"], @"TheParent");
    XCTAssertNil(item[@"child"]);
}

-(void)testReadWithQuery_RecordWithNullPropertyValue
{
    NSError *error;
    NSArray *testArray = @[ @{ @"id" : @"ABC", @"text" : [NSNull null] } ];
    
    [self.store upsertItems:testArray table:TableName orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertEqual(result.items.count, 1);
    
    NSDictionary *item = (result.items)[0];
    
    XCTAssertEqual(item[@"text"], [NSNull null], @"Incorrect text value. Should have been null");
}

-(void)testReadTable_RecordWithNullBooleanValue
{
    NSError *error;
    NSArray *testArray = @[ @{ @"id" : @"ABC", @"boolean": [NSNull null] } ];
    
    [self.store upsertItems:testArray table:@"ColumnTypes" orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:@"ColumnTypes" withItemId:@"ABC" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    
    XCTAssertEqual(item[@"boolean"], [NSNull null]);
}

/** 
 TODO: Root cause on why test fails via xctool, but json serialization works as expected via
 XCode and deployed apps
 *
-(void)testReadTable_RecordWithYesBooleanValue
{
    NSError *error;
    NSArray *testArray = @[ @{ @"id" : @"ABC", @"boolean": @YES } ];
    
    [self.store upsertItems:testArray table:@"ColumnTypes" orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:@"ColumnTypes" withItemId:@"ABC" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    
    NSDictionary *itemWithOnlyBoolean = [item dictionaryWithValuesForKeys:@[ @"boolean" ]];
    
    // We want __NCSFBoolean, not __NCSFNumber, but this is a class cluster, so test that the JSON
    // is a boolean (true/false) and not 1/0.
    NSData *data = [NSJSONSerialization dataWithJSONObject:itemWithOnlyBoolean options:0 error:nil];
    data = [[MSJSONSerializer JSONSerializer] dataFromItem:itemWithOnlyBoolean idAllowed:YES ensureDictionary:NO removeSystemProperties:NO orError:nil];
    NSString *itemAsJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSLog(@"%@", itemAsJson);
    XCTAssertEqualObjects(itemAsJson, @"{\"boolean\":true}");
}
 */

-(void)testReadWithQuery
{
    NSError *error;
    
    [self populateTestData];
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    query.predicate = [NSPredicate predicateWithFormat:@"text == 'test3'"];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result);
    XCTAssertEqual(result.items.count, 1);
    XCTAssertEqual(result.items[0][@"id"], @"C");
}

-(void)testReadWithQuery_Take1_IncludeTotalCount
{
    NSError *error;
    
    [self populateTestData];
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    query.fetchLimit = 1;
    query.includeTotalCount = YES;
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result);
    XCTAssertEqual(result.totalCount, 3);
    XCTAssertEqual(result.items.count, 1);
}

-(void)testReadWithQuery_SortAscending
{
    NSError *error;
    
    [self populateTestData];
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    [query orderByAscending:@"sort"];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result);
    XCTAssertEqual(result.items.count, 3);
    
    NSDictionary *item = (result.items)[0];
    XCTAssertTrue([item[@"id"] isEqualToString:@"C"], @"sort incorrect");
}

-(void)testReadWithQuery_SortDescending
{
    NSError *error;
    
    [self populateTestData];
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    [query orderByDescending:@"sort"];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result, @"result should not have been nil");
    XCTAssertEqual(result.items.count, 3);
    
    NSDictionary *item = result.items[0];
    XCTAssertEqualObjects(item[@"id"], @"B", @"Incorrect sort order");
}

-(void)testReadWithQuery_Select
{
    NSError *error;
    
    [self populateTestData];
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    query.selectFields = @[@"sort", @"text"];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result);
    XCTAssertEqual(result.items.count, 3);
    
    NSDictionary *item = (result.items)[0];
    XCTAssertNil(item[@"id"], @"Unexpected id: %@", item[@"id"]);
    XCTAssertNotNil(item[@"sort"]);
    XCTAssertNotNil(item[@"text"]);
    
    // NOTE: to not break oc, you get version regardless
    XCTAssertNotNil(item[@"version"]);
}

-(void)testReadWithQuery_Select_SystemColumns
{
    NSError *error;
    
    NSArray *testData = @[
      @{ MSSystemColumnId:@"A", @"text": @"t1", MSSystemColumnVersion: @"AAAAAAAAjlg=", @"meaningOfLife": @42},
      @{ MSSystemColumnId:@"B", @"text": @"t2", MSSystemColumnVersion: @"AAAAAAAAjlh=", @"meaningOfLife": @43},
      @{ MSSystemColumnId:@"C", @"text": @"t3", MSSystemColumnVersion: @"AAAAAAAAjli=", @"meaningOfLife": @44}
    ];
    
    [self.store upsertItems:testData table:@"ManySystemColumns" orError:&error];
    XCTAssertNil(error, @"Upsert failed: %@", error.description);
    
    // Now check selecting subset of columns
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:@"ManySystemColumns"
                                                       client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    query.selectFields = @[@"text", @"version", @"meaningOfLife"];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result, @"result should not have been nil");
    XCTAssertEqual(result.items.count, 3);
    
    NSDictionary *item = (result.items)[0];
    XCTAssertNotNil(item[@"text"]);
    XCTAssertNotNil(item[@"meaningOfLife"]);
    XCTAssertNotNil(item[MSSystemColumnVersion]);
    XCTAssertEqual(item.count, 3, @"Select returned extra columns");
}

-(void)testReadWithQuery_NoTable_Error
{
    NSError *error;

    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:@"NoSuchTable" client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSSyncTableLocalStoreError);
}

-(void)testDeleteWithId_Success
{
    NSError *error;
    
    [self populateTestData];
    
    [self.store deleteItemsWithIds:@[@"B"] table:TableName orError:&error];
    XCTAssertNil(error, @"deleteItemsWithIds: failed: %@", error.description);

    NSDictionary *item = [self.store readTable:TableName withItemId:@"B" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNil(item, @"item should have been nil");
}

-(void)testDeleteWithId_MultipleRecords_Success
{
    NSError *error;
    
    [self populateTestData];
    
    [self.store deleteItemsWithIds:@[@"A", @"C"] table:TableName orError:&error];
    XCTAssertNil(error, @"deleteItemsWithIds: failed: %@", error.description);
    
    NSDictionary *item = [self.store readTable:TableName withItemId:@"A" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNil(item, @"item should have been nil");

    item = [self.store readTable:TableName withItemId:@"B" orError:&error];
    XCTAssertNil(error, @"readTable:withItemId: failed: %@", error.description);
    XCTAssertNotNil(item, @"item should not have been nil");
}

-(void)testDeleteWithId_NoRecord_Success
{
    NSError *error;
    
    [self.store deleteItemsWithIds:@[@"B"] table:@"TodoNoVersion" orError:&error];
    XCTAssertNil(error, @"deleteItemsWithIds: failed: %@", error.description);
}

-(void)testDeleteWithIds_NoTable_Error
{
    NSError *error;
    
    [self.store deleteItemsWithIds:@[@"B"] table:@"NoSuchTable" orError:&error];
    
    XCTAssertNotNil(error, @"upsert failed: %@", error.description);
    XCTAssertEqual(error.code, MSSyncTableLocalStoreError);
}

- (void)testDeleteWithQuery_AllRecord_Success
{
    NSError *error;
    
    [self populateTestData];

    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    
    [self.store deleteUsingQuery:query orError:&error];
    XCTAssertNil(error, @"deleteItemsWithIds: failed: %@", error.description);

    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result);
    XCTAssertEqual(result.items.count, 0);
}

- (void)testDeleteWithQuery_Predicate_Success
{
    NSError *error;
    
    [self populateTestData];
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:TableName client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    query.predicate = [NSPredicate predicateWithFormat:@"text == 'test3'"];
    
    [self.store deleteUsingQuery:query orError:&error];
    XCTAssertNil(error, @"deleteItemsWithIds: failed: %@", error.description);
    
    query.predicate = nil;
    MSSyncContextReadResult *result = [self.store readWithQuery:query orError:&error];
    XCTAssertNil(error, @"readWithQuery: failed: %@", error.description);
    XCTAssertNotNil(result, @"result should not have been nil");
    XCTAssertEqual(result.items.count, 2);
    XCTAssertFalse([result.items[0][@"id"] isEqualToString:@"C"], @"Record C should have been deleted");
    XCTAssertFalse([result.items[1][@"id"] isEqualToString:@"C"], @"Record C should have been deleted");
}

-(void)testDeleteWithQuery_NoTable_Error
{
    NSError *error;
    
    MSSyncTable *todoItem = [[MSSyncTable alloc] initWithName:@"NoSuchTable" client:self.client];
    MSQuery *query = [[MSQuery alloc] initWithSyncTable:todoItem predicate:nil];
    query.predicate = [NSPredicate predicateWithFormat:@"text == 'test3'"];
    
    [self.store deleteUsingQuery:query orError:&error];

    XCTAssertNotNil(error, @"upsert failed: %@", error.description);
    XCTAssertEqual(error.code, MSSyncTableLocalStoreError);
}

-(void)testSystemProperties
{
    MSSystemProperties properties = [self.store systemPropertiesForTable:@"ManySystemColumns"];
    XCTAssertEqual(properties, MSSystemPropertyCreatedAt | MSSystemPropertyUpdatedAt | MSSystemPropertyVersion | MSSystemPropertyDeleted);

    properties = [self.store systemPropertiesForTable:TableName];
    XCTAssertEqual(properties, MSSystemPropertyVersion);

    properties = [self.store systemPropertiesForTable:@"TodoItemNoVersion"];
    XCTAssertEqual(properties, MSSystemPropertyNone);
}

-(void)testObjectConversion
{
    [self populateTestData];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:TableName];
    request.predicate = [NSPredicate predicateWithFormat:@"id == %@", @"A"];
    NSArray *results = [self.context executeFetchRequest:request error:nil];
    
    TodoItem *toDoItemObject = results[0];
    // Confirm we are using an internal version column
    XCTAssertEqualObjects(toDoItemObject.version, @"APPLE");
    
    NSDictionary *todoItemDictionary = [self.store tableItemFromManagedObject:toDoItemObject];

    XCTAssertNotNil(todoItemDictionary);
    XCTAssertEqual(todoItemDictionary.count, 4);
    XCTAssertEqualObjects(todoItemDictionary[MSSystemColumnId], @"A");
    XCTAssertEqualObjects(todoItemDictionary[MSSystemColumnVersion], @"APPLE");
    XCTAssertEqualObjects(todoItemDictionary[@"text"], @"test1");
    
    XCTAssertEqualObjects(todoItemDictionary[@"sort"], @10);
}


#pragma mark helper functions 

- (void) populateTestData
{
    NSError *error;
    NSArray *testArray = @[@{@"id":@"A", @"text": @"test1", @"sort":@10, @"version":@"APPLE"},
                          @{@"id":@"B", @"text": @"test2", @"sort":@15, @"version":@"APPLE"},
                          @{@"id":@"C", @"text": @"test3", @"sort":@5, @"version":@"APPLE"}];
    
    [self.store upsertItems:testArray table:TableName orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
}

-(void) populateDefaultParentChild
{
    NSError *error;
    NSArray *testArray = @[ @{
           @"id" : @"P_1",
           @"name" : @"ParentA",
           @"child": @{ @"id": @"C_1", @"value" : @14 }
    } ];
    
    [self.store upsertItems:testArray table:@"Parent" orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
}

-(void) populateDefaultItems
{
    NSError *error;
    NSArray *testArray = @[ @{ @"id" : @"A", @"name" : @"Phone", @"price" : @600 },
                            @{ @"id" : @"B", @"name" : @"Laptop", @"price" : @1500 },
                            @{ @"id" : @"C", @"name" : @"Tablet", @"price" : @800 } ];
    
    [self.store upsertItems:testArray table:TableName orError:&error];
    XCTAssertNil(error, @"upsert failed: %@", error.description);
}

-(NSManagedObject *)lookupRecordWithId:(NSString *)recordId table:(NSString *)table
{
    NSFetchRequest *fr = [[NSFetchRequest alloc] init];
    fr.entity = [NSEntityDescription entityForName:table inManagedObjectContext:self.context];
    fr.predicate = [NSPredicate predicateWithFormat:@"%K ==[c] %@", MSSystemColumnId, recordId];
    
    NSArray<__kindof NSManagedObject *> *results =[self.context executeFetchRequest:fr error:nil];
    
    return results[0];
}

@end
