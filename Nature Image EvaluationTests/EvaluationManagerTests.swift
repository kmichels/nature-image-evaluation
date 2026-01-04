//
//  EvaluationManagerTests.swift
//  Nature Image EvaluationTests
//
//  Created by Claude Code on 01/04/26.
//

@testable import Nature_Image_Evaluation
import XCTest

@MainActor
final class EvaluationManagerTests: XCTestCase {
    var sut: EvaluationManager!
    var testPersistence: PersistenceController!

    override func setUp() async throws {
        try await super.setUp()
        testPersistence = PersistenceController(inMemory: true)
        sut = EvaluationManager(persistenceController: testPersistence)
    }

    override func tearDown() async throws {
        sut = nil
        testPersistence = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_IsNotProcessing() {
        XCTAssertFalse(sut.isProcessing)
    }

    func testInitialState_HasEmptyQueue() {
        XCTAssertTrue(sut.evaluationQueue.isEmpty)
    }

    func testInitialState_ProgressIsZero() {
        XCTAssertEqual(sut.currentProgress, 0)
    }

    func testInitialState_HasReadyStatusMessage() {
        XCTAssertFalse(sut.statusMessage.isEmpty)
    }

    func testInitialState_HasNoError() {
        XCTAssertNil(sut.currentError)
    }

    func testInitialState_CountersAreZero() {
        XCTAssertEqual(sut.successfulEvaluations, 0)
        XCTAssertEqual(sut.failedEvaluations, 0)
        XCTAssertEqual(sut.currentBatch, 0)
        XCTAssertEqual(sut.totalBatches, 0)
    }

    // MARK: - Queue Management Tests

    func testClearQueue_RemovesAllItems() {
        // Even if queue is already empty, clearQueue should work
        sut.clearQueue()
        XCTAssertTrue(sut.evaluationQueue.isEmpty)
    }

    // MARK: - Configuration Tests

    func testConfiguration_HasDefaultRequestDelay() {
        XCTAssertEqual(sut.requestDelay, Constants.defaultRequestDelay)
    }

    func testConfiguration_HasDefaultMaxBatchSize() {
        XCTAssertEqual(sut.maxBatchSize, Constants.maxBatchSize)
    }

    func testConfiguration_HasDefaultImageResolution() {
        XCTAssertEqual(sut.imageResolution, Constants.maxImageDimension)
    }

    func testConfiguration_CanUpdateRequestDelay() {
        sut.requestDelay = 2.0
        XCTAssertEqual(sut.requestDelay, 2.0)
    }

    func testConfiguration_CanUpdateMaxBatchSize() {
        sut.maxBatchSize = 5
        XCTAssertEqual(sut.maxBatchSize, 5)
    }

    // MARK: - Provider Tests

    func testDefaultProvider_IsAnthropic() {
        XCTAssertEqual(sut.selectedProvider, .anthropic)
    }

    func testCanChangeProvider() {
        sut.selectedProvider = .openai
        XCTAssertEqual(sut.selectedProvider, .openai)
    }
}
