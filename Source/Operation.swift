//
//  Operation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/25/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Operation arithmetic.

 Define the available arithmetic for operation.
 */
protocol OperationArithmetic {
    func add(operation: Operation) -> Operation?
}

func + (left: Operation, right: Operation) -> Operation? {
    return left.add(right)
}

/**
 Operation.

 Used to present an action of object update.
 */
class Operation: OperationArithmetic {
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

    /**
     Merge previous operation.

     - parameter operation: Operation to be merged.

     - returns: A new merged operation.
     */
    func merge(operation: Operation) -> Operation? {
        let left = operation
        let right = self

        /* Check every cases to if merge is possible.
         * Permutation can be generated by echo {}{} syntax.
         */
        switch (left.name, right.name) {
        case (.Set, .Set): return right
        case (.Set, .Delete): return right
        case (.Set, .Increment): return left + right
        // case (.Set, .Add):
        // case (.Set, .AddUnique):
        // case (.Set, .AddRelation):
        // case (.Set, .Remove):
        // case (.Set, .RemoveRelation):
        // case (.Delete, .Set):
        // case (.Delete, .Delete):
        // case (.Delete, .Increment):
        // case (.Delete, .Add):
        // case (.Delete, .AddUnique):
        // case (.Delete, .AddRelation):
        // case (.Delete, .Remove):
        // case (.Delete, .RemoveRelation):
        // case (.Increment, .Set):
        // case (.Increment, .Delete):
        // case (.Increment, .Increment):
        // case (.Increment, .Add):
        // case (.Increment, .AddUnique):
        // case (.Increment, .AddRelation):
        // case (.Increment, .Remove):
        // case (.Increment, .RemoveRelation):
        // case (.Add, .Set):
        // case (.Add, .Delete):
        // case (.Add, .Increment):
        // case (.Add, .Add):
        // case (.Add, .AddUnique):
        // case (.Add, .AddRelation):
        // case (.Add, .Remove):
        // case (.Add, .RemoveRelation):
        // case (.AddUnique, .Set):
        // case (.AddUnique, .Delete):
        // case (.AddUnique, .Increment):
        // case (.AddUnique, .Add):
        // case (.AddUnique, .AddUnique):
        // case (.AddUnique, .AddRelation):
        // case (.AddUnique, .Remove):
        // case (.AddUnique, .RemoveRelation):
        // case (.AddRelation, .Set):
        // case (.AddRelation, .Delete):
        // case (.AddRelation, .Increment):
        // case (.AddRelation, .Add):
        // case (.AddRelation, .AddUnique):
        // case (.AddRelation, .AddRelation):
        // case (.AddRelation, .Remove):
        // case (.AddRelation, .RemoveRelation):
        // case (.Remove, .Set):
        // case (.Remove, .Delete):
        // case (.Remove, .Increment):
        // case (.Remove, .Add):
        // case (.Remove, .AddUnique):
        // case (.Remove, .AddRelation):
        // case (.Remove, .Remove):
        // case (.Remove, .RemoveRelation):
        // case (.RemoveRelation, .Set):
        // case (.RemoveRelation, .Delete):
        // case (.RemoveRelation, .Increment):
        // case (.RemoveRelation, .Add):
        // case (.RemoveRelation, .AddUnique):
        // case (.RemoveRelation, .AddRelation):
        // case (.RemoveRelation, .Remove):
        // case (.RemoveRelation, .RemoveRelation):
        default:
            break
        }

        return self
    }

    // MARK: Arithmetic

    /**
     Add two operations to be one operation.

     This is a stub method for overriding, default implementation will throw an exception.

     - parameter operation: Another operation.

     - returns: Adding result.
     */
    func add(operation: Operation) -> Operation? {
        /* TODO: throw an exception that two operations cannot be added. */
        return nil
    }

    // MARK: Operation Subclasses

    class Set: Operation {
        override func add(operation: Operation) -> Operation? {
            var value: LCType?

            /* SET then INCREMENT is valid for number types.
               SET then ADD or ADDUNIQUE is valid for sequence types. */
            switch operation.name {
            case .Increment, .Add:
                /* SET operation's value cannot be nil, or it's a DELETE operation.
                   So, We are safe to unwrap the optional here. */
                value = self.value!.add(operation.value)
            case .AddUnique:
                value = self.value!.add(operation.value, unique: true)
            default:
                /* TODO: throw an exception that two operations cannot be added. */
                break
            }

            if let value = value {
                return Operation(name: .Set, key: key, value: value)
            } else {
                return nil
            }
        }
    }

    class Delete: Operation {
        /* Stub class */
    }

    class Increment: Operation {
        /* Stub class */
    }

    class Add: Operation {
        /* Stub class */
    }

    class AddUnique: Operation {
        /* Stub class */
    }

    class AddRelation: Operation {
        /* Stub class */
    }

    class Remove: Operation {
        /* Stub class */
    }

    class RemoveRelation: Operation {
        /* Stub class */
    }

    static func subclass(operationName name: Operation.Name) -> AnyClass {
        var subclass: AnyClass

        switch name {
        case .Set:            subclass = Operation.Set.self
        case .Delete:         subclass = Operation.Delete.self
        case .Increment:      subclass = Operation.Increment.self
        case .Add:            subclass = Operation.Add.self
        case .AddUnique:      subclass = Operation.AddUnique.self
        case .AddRelation:    subclass = Operation.AddRelation.self
        case .Remove:         subclass = Operation.Remove.self
        case .RemoveRelation: subclass = Operation.RemoveRelation.self
        }

        return subclass
    }
}

/**
 Operation hub.

 Used to manage a batch of operations.
 */
class OperationHub {
    weak var object: LCObject!

    /// A list of all operations.
    lazy var operations = [Operation]()

    /// A table of non-redundant operations indexed by operation key.
    lazy var operationTable: [String:Operation] = [:]

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
        let subclass  = Operation.subclass(operationName: name) as! Operation.Type
        let operation = subclass.init(name: name, key: key, value: value)

        operations.append(operation)
        reduce(operation)
    }

    /**
     Reduce operation to operation table.

     - parameter operation: The operation which you want to reduce.
     */
    func reduce(operation: Operation) {
        var newOperation = operation

        /* Merge with previous operation which has the same key. */
        if let previousOperation = operationTable[operation.key] {
            if let mergedOperation = operation.merge(previousOperation) {
                newOperation = mergedOperation
            }
        }

        if newOperation !== operation {
            ObjectProfiler.updateProperty(object, operation.key, propertyValue: newOperation.value)
        }

        operationTable[operation.key] = newOperation
    }

    /**
     Produce a payload dictionary for request.

     - returns: A payload dictionary.
     */
    func payload() -> NSDictionary {
        return [:]
    }
}