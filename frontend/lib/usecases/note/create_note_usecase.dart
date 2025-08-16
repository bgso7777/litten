import '../../services/models/note_model.dart';

/// 리튼(노트) 생성 Use Case
/// 
/// 비즈니스 규칙:
/// - 무료 사용자는 최대 5개의 리튼만 생성 가능
/// - 스탠다드/프리미엄 사용자는 무제한 생성 가능
/// - 리튼 제목은 필수이며 중복될 수 있음
class CreateNoteUseCase {
  // 노트 생성 비즈니스 로직
  Future<NoteModel> execute({
    required String title,
    required bool isPremiumUser,
    required int currentNoteCount,
  }) async {
    // 무료 사용자 제한 검증
    if (!isPremiumUser && currentNoteCount >= 5) {
      throw Exception('무료 버전에서는 최대 5개의 리튼만 생성할 수 있습니다.');
    }
    
    // 제목 유효성 검증
    if (title.trim().isEmpty) {
      throw Exception('리튼 제목을 입력해주세요.');
    }
    
    // 새 노트 생성
    final note = NoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      audioFiles: [],
      textFiles: [],
      handwritingFiles: [],
    );
    
    return note;
  }
}