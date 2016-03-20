//
//  Operation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/25/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Operation.

 Used to present an action of object update.
 */
class Operation {
    /**
     Operation Name.
     */
    enum Name: String {
        case Set            = "Set"
        case Delete         = "Delete"
        case Increment      = "Increment"
        case Add            = "Add"
        case AddUnique      = "AddUnique"
        case AddRelation    = "AddRelation"
        case Remove         = "Remove"
        case RemoveRelation = "RemoveRelation"
    }

    let name: Name
    let key: String
    let value: LCType?

    required init(name: Name, key: String, value: LCType?) {
        self.name  = name
        self.key   = key
        self.value = value
    }
}

typealias OperationPile      = [String:[Operation]]
typealias OperationTable     = [String:Operation]
typealias OperationTableList = [OperationTable]

/**
 Operation hub.

 Used to manage a batch of operations.
 */
class OperationHub {
    weak var object: LCObject!

    /// A list of all operations.
    lazy var operations = [Operation]()

    /// A table of operation reducer indexed by operation key.
    lazy var operationReducerTable: [String:OperationReducer] = [:]

    init(_ object: LCObject) {
        self.object = object
    }

    /**
     Append an operation to hub.

     - parameter name:  Operation name.
     - parameter key:   Key on which to perform.
     - parameter value: Value to be assigned.
     */
    func append(name: Operation.Name, _ key: String, _ value: LCType?) {
        let copyValue = value?.copy() as? LCType
        let operation = Operation(name: name, key: key, value: copyValue)
        operations.append(operation)
        reduce(operation)
    }

    /**
     Reduce operation to operation table.

     - parameter operation: The operation which you want to reduce.
     */
    func reduce(operation: Operation) {
        let reducer = operationReducer(operation)

        reducer.validate(operation)
        reducer.reduce(operation)
    }

    /**
     Get operation reducer for operation.

     - parameter operation: The operation to be reduced.

     - returns: The operation reducer to reduce the given operation.
     */
    func operationReducer(operation: Operation) -> OperationReducer {
        let key = operation.key

        if let previousOperationReducer = operationReducerTable[key] {
            return previousOperationReducer
        } else {
            let operationReducer = operationReducerSubclass(object, key).init()
            operationReducerTable[key] = operationReducer
            return operationReducer
        }
    }

    /**
     Get operation reducer class of an object property.

     - parameter object:       The object to be inspected.
     - parameter propertyName: The property name of object.

     - returns: The concrete operation reducer subclass.
     */
    func operationReducerSubclass(object: LCObject, _ propertyName: String) -> OperationReducer.Type {
        let subclass = ObjectProfiler.getLCType(object: object, propertyName: propertyName) as LCType.Type!
        return subclass.operationReducerType()
    }

    /**
     Get an operation pile.

     The operation pile is a structure that maps operation key to a list of operations.

     - returns: An operation pile indexed by property key.
     */
    func operationPile() -> OperationPile {
        var operationPile: OperationPile = [:]

        operationReducerTable.forEach { (key, operationReducer) in
            let operations = operationReducer.operations()

            if operations.count > 0 {
                operationPile[key] = operations
            }
        }

        return operationPile
    }

    /**
     Extract an operation table from an operation pile.

     - parameter operationPile: An operation pile from which the operation table will be extracted.

     - returns: An operation table, or nil if no operations can be extracted.
     */
    func extractOperationTable(inout operationPile: OperationPile) -> OperationTable? {
        var table: OperationTable = [:]

        operationPile.forEach { (key, var operations) in
            if operations.isEmpty {
                operationPile.removeValueForKey(key)
            } else {
                table[key] = operations.removeAtIndex(0)
                operationPile[key] = operations
            }
        }

        return table.isEmpty ? nil : table
    }

    /**
     Get an operation table list.

     Operation table list is flat version of operation pile.
     When a key has two or more operations in operation pile,
     each operation will be extracted to each operation table in an operation table list.

     For example, `["foo":[op1,op2]]` will extracted as `[["foo":op1],["foo":op2]]`.

     The reason for making this transformation is that one request should
     not contain multiple operations on one key.

     - returns: An operation table list.
     */
    func operationTableList() -> OperationTableList {
        var list: OperationTableList = []
        var operationPile = self.operationPile()

        while !operationPile.isEmpty {
            if let operationTable = extractOperationTable(&operationPile) {
                list.append(operationTable)
            }
        }

        return list
    }

    /**
     Produce a payload dictionary for request.

     - returns: A payload dictionary.
     */
    func payload() -> NSDictionary {
        return [:]
    }
}

/**
 Operation reducer.

 Operation reducer is used to reduce operations to remove redundancy.
 */
class OperationReducer {
    required init() {
        /* Stub method. */
    }

    class func validOperationNames() -> [Operation.Name] {
        return []
    }

    /**
     Validate operation.

     - parameter operation: The operation to validate.
     */
    func validate(operation: Operation) {
        let operationNames = self.dynamicType.validOperationNames()

        guard operationNames.contains(operation.name) else {
            /* TODO: throw an exception that current reducer cannot reduce operation. */
            return
        }
    }

    /**
     Reduce another operation.

     - parameter operation: The operation to be reduced.
     */
    func reduce(operation: Operation) {
        /* TODO: throw an exception that current reducer cannot reduce operation. */
    }

    /**
     Get all reduced operations.

     - returns: An array of reduced operations.
     */
    func operations() -> [Operation] {
        return []
    }

    /**
     Key oriented operation.

     It only accepts following operations:

     - SET
     - DELETE
     */
    class Key: OperationReducer {
        var operation: Operation?

        override class func validOperationNames() -> [Operation.Name] {
            return [.Set, .Delete]
        }

        override func reduce(operation: Operation) {
            /* SET or DELETE will always override the previous. */
            self.operation = operation
        }

        override func operations() -> [Operation] {
            return (operation != nil) ? [operation!] : []
        }
    }

    /**
     Number oriented operation.

     It only accepts following operations:

     - SET
     - DELETE
     - INCREMENT
     */
    class Number: OperationReducer {
        var operation: Operation?

        override class func validOperationNames() -> [Operation.Name] {
            return [.Set, .Delete, .Increment]
        }

        override func reduce(operation: Operation) {
            if let previousOperation = self.operation {
                self.operation = reduce(operation, previousOperation: previousOperation)
            } else {
                self.operation = operation
            }
        }

        func reduce(operation: Operation, previousOperation: Operation) -> Operation? {
            let left  = previousOperation
            let right = operation

            switch (left.name, right.name) {
            case (.Set,       .Set):       return right
            case (.Delete,    .Set):       return right
            case (.Increment, .Set):       return right
            case (.Set,       .Delete):    return right
            case (.Delete,    .Delete):    return right
            case (.Increment, .Delete):    return right
            case (.Set,       .Increment): return Operation(name: .Set,       key: operation.key, value: left.value! + right.value!)
            case (.Delete,    .Increment): return Operation(name: .Set,       key: operation.key, value: right.value)
            case (.Increment, .Increment): return Operation(name: .Increment, key: operation.key, value: left.value! + right.value!)
            default:                       return nil
            }
        }

        override func operations() -> [Operation] {
            return (operation != nil) ? [operation!] : []
        }
    }

    /**
     List oriented operation.

     It only accepts following operations:

     - SET
     - DELETE
     - ADD
     - ADDUNIQUE
     - REMOVE
     */
    class List: OperationReducer {
        var operationTable: [Operation.Name:Operation] = [:]

        override class func validOperationNames() -> [Operation.Name] {
            return [.Set, .Delete, .Add, .AddUnique, .Remove]
        }

        override func reduce(operation: Operation) {
            switch operation.name {
            case .Set:
                reset()
                setOperation(operation)
            case .Delete:
                reset()
                setOperation(operation)
            case .Add:
                removeObjects(operation, [.AddUnique, .Remove])

                if hasOperation(.Set) || hasOperation(.Delete) {
                    addObjects(operation, .Set)
                } else {
                    addObjects(operation, .Add)
                }
            case .AddUnique:
                removeObjects(operation, [.Add, .Remove])

                if hasOperation(.Set) || hasOperation(.Delete) {
                    unionObjects(operation, .Set)
                } else {
                    unionObjects(operation, .AddUnique)
                }
            case .Remove:
                removeObjects(operation, [.Set, .Add, .AddUnique])
                unionObjects(operation, .Remove)
            default:
                break
            }
        }

        override func operations() -> [Operation] {
            var operationTable = self.operationTable
            removeEmptyOperation(&operationTable, [.Add, .AddUnique, .Remove])
            return Array(operationTable.values)
        }

        /**
         Remove empty operations from operation table.

         - parameter operationTable: The operation table.
         - parameter operationNames: A set of operation names that specify which operation should be removed from operation table if it is empty.
         */
        func removeEmptyOperation(inout operationTable: [Operation.Name:Operation], _ operationNames:Set<Operation.Name>) {
            operationNames.forEach { (operationName) in
                if let operation = operationTable[operationName] {
                    if !hasObjects(operation) {
                        operationTable[operationName] = nil
                    }
                }
            }
        }

        /**
         Check whether an operation has objects.

         - parameter operation: The operation.

         - returns: true if operation has objects, false otherwise.
         */
        func hasObjects(operation: Operation) -> Bool {
            if let list = operation.value as? LCArray {
                return list.value?.count > 0
            } else {
                return false
            }
        }

        /**
         Check whether an operation existed for given operation name.

         - parameter name: The operation name.

         - returns: true if operation existed for operation name, false otherwise.
         */
        func hasOperation(name: Operation.Name) -> Bool {
            return operationTable[name] != nil
        }

        /**
         Remove objects in an operation from operations specified by a set of operation names.

         - parameter operation:      The operation that contains objects to be removed.
         - parameter operationNames: A set of operation names that specify operations from which the objects will be removed.
         */
        func removeObjects(operation: Operation, _ operationNames: Set<Operation.Name>) {
            var operations: [Operation] = []
            let subtrahend = operation.value as! LCArray

            operationTable.forEach { (operationName, operation) in
                guard operationNames.contains(operationName)   else { return }
                guard let minuend = operation.value as? LCArray else { return }

                operations.append(Operation(name: operation.name, key: operation.key, value: minuend - subtrahend))
            }

            operations.forEach { setOperation($0) }
        }

        /**
         Add objects in an operation from operation specified by operation name.

         - parameter operation:     The operation that contains objects to be removed.
         - parameter operationName: The operation name that specifies operation from which the objects will be removed.
         */
        func addObjects(operation: Operation, _ operationName: Operation.Name) {
            var value = operation.value

            if let baseValue = operationTable[operationName]?.value as? LCArray {
                value = baseValue + value
            }

            let operation = Operation(name: operationName, key: operation.key, value: value)

            setOperation(operation)
        }

        /**
         Union objects in an operation into operation specified by operation name.

         - parameter operation:     The operation that contains objects to be unioned.
         - parameter operationName: The operation name that specifies operation into which the objects will be unioned.
         */
        func unionObjects(operation: Operation, _ operationName: Operation.Name) {
            var value = operation.value

            if let baseValue = operationTable[operationName]?.value as? LCArray {
                value = baseValue +~ value
            }

            let operation = Operation(name: operationName, key: operation.key, value: value)

            setOperation(operation)
        }

        /**
         Set operation to operation table.

         - parameter operation: The operation to set.
         */
        func setOperation(operation: Operation) {
            self.operationTable[operation.name] = operation
        }

        /**
         Reset operation table.
         */
        func reset() {
            self.operationTable = [:]
        }
    }

    /**
     Relation oriented operation.

     It only accepts following operations:

     - ADDRELATION
     - REMOVERELATION
     */
    class Relation: OperationReducer {
        /* Stub class. */
    }
}