import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct RecordViewModelRedesignTests {
    @Test("新しいタグは確定するとチップ用の入力になり、複数追加できる")
    func confirmsMultipleNewTags() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.tags = [Tag(id: 1, name: "STECH")]
        viewModel.newTagName = "ハッカソン"

        viewModel.addNewTag()
        viewModel.newTagName = "LT会"
        viewModel.addNewTag()
        viewModel.newTagName = "stech"
        viewModel.addNewTag()

        #expect(viewModel.newTagName.isEmpty)
        #expect(viewModel.addedTagNames == ["ハッカソン", "LT会"])
        #expect(viewModel.selectedTagNames == ["STECH"])
        #expect(viewModel.tagNamesForSubmission == ["STECH", "ハッカソン", "LT会"])
    }

    @Test("保存直後は下書きを入力欄へ戻せる")
    func restoresDraftAfterSaving() async {
        let client = StubRecordAPIClient()
        client.peopleResults = [.success([]), .success([])]
        client.tagResults = [.success([]), .success([])]
        let viewModel = RecordViewModel(client: client)
        let selectedPerson = person(id: 1, name: "たなか")
        viewModel.select(person: selectedPerson)
        viewModel.topic = "勉強会"
        viewModel.memo = "次にRailsの話をする"
        viewModel.addedTagNames = ["STECH", "LT会"]

        await viewModel.save()

        #expect(viewModel.didSave)
        #expect(viewModel.lastSavedPersonName == "たなか")
        #expect(viewModel.name.isEmpty)

        await viewModel.undoLastSavedRecord()

        #expect(!viewModel.didSave)
        #expect(client.deleteCalls == [StubRecordAPIClient.DeleteEncounterCall(id: 1, removeEmptyPerson: false)])
        #expect(viewModel.selectedPerson?.id == 1)
        #expect(viewModel.name == "たなか")
        #expect(viewModel.topic == "勉強会")
        #expect(viewModel.memo == "次にRailsの話をする")
        #expect(viewModel.addedTagNames == ["STECH", "LT会"])
    }

    @Test("既存人物の選択を明示的に解除すると新しい名前を入力できる")
    func clearsSelectedPerson() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.select(person: person(id: 1, name: "たなか"))

        viewModel.clearSelectedPerson()

        #expect(viewModel.selectedPerson == nil)
        #expect(viewModel.name.isEmpty)
    }

    @Test("新規人物の記録を取り消すと空の人物も削除する")
    func removesEmptyPersonWhenUndoingNewPersonRecord() async {
        let client = StubRecordAPIClient()
        client.peopleResults = [.success([]), .success([])]
        client.tagResults = [.success([]), .success([])]
        let viewModel = RecordViewModel(client: client)
        viewModel.updateName("新しい人")

        await viewModel.save()
        await viewModel.undoLastSavedRecord()

        #expect(client.deleteCalls == [StubRecordAPIClient.DeleteEncounterCall(id: 1, removeEmptyPerson: true)])
        #expect(viewModel.name == "新しい人")
    }
}
