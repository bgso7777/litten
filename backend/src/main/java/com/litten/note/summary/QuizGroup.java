package com.litten.note.summary;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
public class RemindGroup {
    private String groupName;                      // 1단 항목명
    private List<RemindItem> items = new ArrayList<>();  // 2~3단 세부항목
}
