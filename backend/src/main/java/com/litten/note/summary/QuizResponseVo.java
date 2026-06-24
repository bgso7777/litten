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
