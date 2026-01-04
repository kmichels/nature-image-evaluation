//
//  SmartFolderCriteria.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/14/25.
//

import Foundation

// MARK: - Smart Folder Criteria Model

struct SmartFolderCriteria: Codable {
    var rules: [CriteriaRule]
    var matchAll: Bool // true = AND, false = OR

    init(rules: [CriteriaRule] = [], matchAll: Bool = true) {
        self.rules = rules
        self.matchAll = matchAll
    }
}

struct CriteriaRule: Codable, Identifiable {
    var id = UUID()
    var criteriaType: CriteriaType
    var comparison: ComparisonOperator
    var value: CriteriaValue

    enum CriteriaType: String, Codable, CaseIterable {
        case overallScore = "Overall Score"
        case compositionScore = "Composition Score"
        case qualityScore = "Quality Score"
        case sellabilityScore = "Sellability Score"
        case artisticScore = "Artistic Score"
        case placement = "Placement"
        case evaluationStatus = "Evaluation Status"
        case dateAdded = "Date Added"
        case dateEvaluated = "Date Evaluated"
        case favorite = "Favorite"

        var keyPath: String {
            switch self {
            case .overallScore:
                return "currentEvaluation.overallWeightedScore"
            case .compositionScore:
                return "currentEvaluation.compositionScore"
            case .qualityScore:
                return "currentEvaluation.qualityScore"
            case .sellabilityScore:
                return "currentEvaluation.sellabilityScore"
            case .artisticScore:
                return "currentEvaluation.artisticScore"
            case .placement:
                return "currentEvaluation.primaryPlacement"
            case .evaluationStatus:
                return "currentEvaluation"
            case .dateAdded:
                return "dateAdded"
            case .dateEvaluated:
                return "dateLastEvaluated"
            case .favorite:
                return "isFavorite"
            }
        }

        var valueType: CriteriaValue.ValueType {
            switch self {
            case .overallScore, .compositionScore, .qualityScore, .sellabilityScore, .artisticScore:
                return .number
            case .placement:
                return .placement
            case .evaluationStatus:
                return .boolean
            case .dateAdded, .dateEvaluated:
                return .date
            case .favorite:
                return .boolean
            }
        }

        var availableComparisons: [ComparisonOperator] {
            switch valueType {
            case .number:
                return [.equal, .notEqual, .greaterThan, .lessThan, .greaterThanOrEqual, .lessThanOrEqual]
            case .placement:
                return [.equal, .notEqual]
            case .boolean:
                return [.equal]
            case .date:
                return [.greaterThan, .lessThan, .inLast]
            }
        }
    }

    enum ComparisonOperator: String, Codable, CaseIterable {
        case equal = "is"
        case notEqual = "is not"
        case greaterThan = "is greater than"
        case lessThan = "is less than"
        case greaterThanOrEqual = "is at least"
        case lessThanOrEqual = "is at most"
        case inLast = "in the last"

        var predicateOperator: String {
            switch self {
            case .equal:
                return "=="
            case .notEqual:
                return "!="
            case .greaterThan:
                return ">"
            case .lessThan:
                return "<"
            case .greaterThanOrEqual:
                return ">="
            case .lessThanOrEqual:
                return "<="
            case .inLast:
                return ">="
            }
        }
    }
}

enum CriteriaValue: Codable {
    case number(Double)
    case string(String)
    case boolean(Bool)
    case date(Date)
    case dateInterval(DateComponents)
    case placement(String)

    enum ValueType {
        case number
        case placement
        case boolean
        case date
    }

    var displayValue: String {
        switch self {
        case let .number(value):
            return String(format: "%.1f", value)
        case let .string(value):
            return value
        case let .boolean(value):
            return value ? "Yes" : "No"
        case let .date(value):
            return Formatters.mediumDate.string(from: value)
        case let .dateInterval(components):
            if let days = components.day {
                return "\(days) days"
            } else if let weeks = components.weekOfYear {
                return "\(weeks) weeks"
            } else if let months = components.month {
                return "\(months) months"
            }
            return "Unknown"
        case let .placement(value):
            return value
        }
    }
}

// MARK: - Predicate Builder

extension SmartFolderCriteria {
    func buildPredicate() -> NSPredicate? {
        guard !rules.isEmpty else { return nil }

        let predicates = rules.compactMap { rule -> NSPredicate? in
            switch rule.criteriaType {
            case .overallScore, .compositionScore, .qualityScore, .sellabilityScore, .artisticScore:
                guard case let .number(value) = rule.value else { return nil }
                return NSPredicate(format: "%K \(rule.comparison.predicateOperator) %f",
                                   rule.criteriaType.keyPath, value)

            case .placement:
                guard case let .placement(value) = rule.value else { return nil }
                if rule.comparison == .equal {
                    return NSPredicate(format: "%K == %@", rule.criteriaType.keyPath, value)
                } else {
                    return NSPredicate(format: "%K != %@", rule.criteriaType.keyPath, value)
                }

            case .evaluationStatus:
                guard case let .boolean(value) = rule.value else { return nil }
                if value {
                    return NSPredicate(format: "currentEvaluation != nil")
                } else {
                    return NSPredicate(format: "currentEvaluation == nil")
                }

            case .dateAdded, .dateEvaluated:
                if case let .date(date) = rule.value {
                    return NSPredicate(format: "%K \(rule.comparison.predicateOperator) %@",
                                       rule.criteriaType.keyPath, date as NSDate)
                } else if case let .dateInterval(components) = rule.value,
                          rule.comparison == .inLast
                {
                    let date = Calendar.current.date(byAdding: components, to: Date())!
                    return NSPredicate(format: "%K >= %@", rule.criteriaType.keyPath, date as NSDate)
                }
                return nil

            case .favorite:
                guard case let .boolean(value) = rule.value else { return nil }
                return NSPredicate(format: "%K == %@", rule.criteriaType.keyPath, NSNumber(value: value))
            }
        }

        guard !predicates.isEmpty else { return nil }

        if matchAll {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } else {
            return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }
    }

    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func fromJSONString(_ json: String) -> SmartFolderCriteria? {
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(SmartFolderCriteria.self, from: data)
    }
}

// MARK: - Predefined Templates

extension SmartFolderCriteria {
    static var portfolioQuality: SmartFolderCriteria {
        SmartFolderCriteria(rules: [
            CriteriaRule(criteriaType: .overallScore, comparison: .greaterThanOrEqual, value: .number(8.0)),
            CriteriaRule(criteriaType: .placement, comparison: .equal, value: .placement("PORTFOLIO")),
        ], matchAll: false)
    }

    static var needsReview: SmartFolderCriteria {
        SmartFolderCriteria(rules: [
            CriteriaRule(criteriaType: .evaluationStatus, comparison: .equal, value: .boolean(false)),
        ], matchAll: true)
    }

    static var recentlyAdded: SmartFolderCriteria {
        var components = DateComponents()
        components.day = -7
        return SmartFolderCriteria(rules: [
            CriteriaRule(criteriaType: .dateAdded, comparison: .inLast, value: .dateInterval(components)),
        ], matchAll: true)
    }

    static var highCommercialValue: SmartFolderCriteria {
        SmartFolderCriteria(rules: [
            CriteriaRule(criteriaType: .sellabilityScore, comparison: .greaterThanOrEqual, value: .number(8.5)),
            CriteriaRule(criteriaType: .placement, comparison: .equal, value: .placement("STORE")),
        ], matchAll: false)
    }

    static var needsImprovement: SmartFolderCriteria {
        SmartFolderCriteria(rules: [
            CriteriaRule(criteriaType: .overallScore, comparison: .lessThan, value: .number(5.0)),
            CriteriaRule(criteriaType: .placement, comparison: .equal, value: .placement("ARCHIVE")),
        ], matchAll: false)
    }

    static var favorites: SmartFolderCriteria {
        SmartFolderCriteria(rules: [
            CriteriaRule(criteriaType: .favorite, comparison: .equal, value: .boolean(true)),
        ], matchAll: true)
    }
}
