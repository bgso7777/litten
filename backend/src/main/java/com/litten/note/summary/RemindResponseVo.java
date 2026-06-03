package com.litten.note.summary;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
public class RemindResponseVo {
    private boolean success;
    private List<RemindGroup> reminds;
    private int totalRemindCount;
    private String error;

    public static RemindResponseVo ok(List<RemindGroup> groups) {
        RemindResponseVo vo = new RemindResponseVo();
        vo.success = true;
        vo.reminds = groups;
        vo.totalRemindCount = groups.stream().mapToInt(g -> g.getItems().size()).sum();
        return vo;
    }

    public static RemindResponseVo fail(String error) {
        RemindResponseVo vo = new RemindResponseVo();
        vo.success = false;
        vo.error = error;
        return vo;
    }
}
