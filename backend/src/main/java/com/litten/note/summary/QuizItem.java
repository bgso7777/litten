package com.litten.note.summary;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
public class QuizItem {
    private String type;       // 일정|액션|핵심개념|적용포인트|학습할것|외부대기|리스크|기타
    private String content;    // 세부항목 내용
    private String assignee;   // 담당자
    private String deadline;   // 기한
    private List<String> details = new ArrayList<>();  // 3단 부가 설명
}
