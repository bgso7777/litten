package com.litten.note.summary;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
public class QuizResponseVo {
    private boolean success;
    /** 퀴즈가 저장된 note_summary_result PK — 클라이언트가 이후 조회/재생성에 사용 */
    private Long summaryResultId;
    private List<QuizGroup> quizzes;
    private int totalQuizCount;
    private String error;

    public static QuizResponseVo ok(List<QuizGroup> groups) {
        QuizResponseVo vo = new QuizResponseVo();
        vo.success = true;
        vo.quizzes = groups;
        vo.totalQuizCount = groups.stream().mapToInt(g -> g.getItems().size()).sum();
        return vo;
    }

    public static QuizResponseVo fail(String error) {
        QuizResponseVo vo = new QuizResponseVo();
        vo.success = false;
        vo.error = error;
        return vo;
    }
}
