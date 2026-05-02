package com.litten.note.summary;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class SummaryResponseVo {
    private boolean success;
    private String summary;
    private String error;

    public static SummaryResponseVo ok(String summary) {
        return new SummaryResponseVo(true, summary, null);
    }

    public static SummaryResponseVo fail(String error) {
        return new SummaryResponseVo(false, null, error);
    }
}
