package com.litten.note.share;

import com.litten.common.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.log4j.Log4j2;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 공유 그룹 API. 로그인 회원(소유자) 전용.
 *  POST   /note/v1/share-groups                       그룹 생성 {name}
 *  GET    /note/v1/share-groups                       내 그룹 목록
 *  DELETE /note/v1/share-groups/{groupId}             그룹 삭제
 *  GET    /note/v1/share-groups/{groupId}/members     멤버 목록
 *  POST   /note/v1/share-groups/{groupId}/members     멤버 추가 {key=이메일/이름}
 *  DELETE /note/v1/share-groups/{groupId}/members?memberId=  멤버 제거
 */
@Log4j2
@RestController
@RequiredArgsConstructor
public class ShareGroupController {

    private final ShareGroupService groupService;

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/share-groups")
    public ResponseEntity<Map<String, Object>> createGroup(@RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        try {
            String name = (String) body.get("name");
            String password = body.get("password") != null ? body.get("password").toString() : null;
            List<String> members = null;
            if (body.get("members") instanceof List<?> raw) {
                members = raw.stream().map(Object::toString).toList();
            }
            Map<String, Object> g = groupService.createGroup(memberId, name, password, members);
            return ok(Map.of("group", g));
        } catch (IllegalArgumentException e) {
            return badRequest(e.getMessage());
        }
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/share-groups")
    public ResponseEntity<Map<String, Object>> listGroups() {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        List<Map<String, Object>> groups = groupService.listGroups(memberId);
        return ok(Map.of("groups", groups));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping("/note/v1/share-groups/{groupId}")
    public ResponseEntity<Map<String, Object>> deleteGroup(@PathVariable Long groupId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        boolean ok = groupService.deleteGroup(memberId, groupId);
        if (!ok) return badRequest("그룹을 찾을 수 없습니다.");
        return ok(Map.of("message", "삭제 완료"));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @GetMapping("/note/v1/share-groups/{groupId}/members")
    public ResponseEntity<Map<String, Object>> listMembers(@PathVariable Long groupId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        return ok(Map.of("members", groupService.listMembers(memberId, groupId)));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @PostMapping("/note/v1/share-groups/{groupId}/members")
    public ResponseEntity<Map<String, Object>> addMember(@PathVariable Long groupId,
                                                         @RequestBody Map<String, Object> body) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        Map<String, Object> added = groupService.addMember(memberId, groupId, (String) body.get("key"));
        if (added == null) return badRequest("회원을 찾을 수 없거나 그룹 권한이 없습니다.");
        return ok(Map.of("member", added));
    }

    @CrossOrigin(origins = "*", allowedHeaders = "*")
    @DeleteMapping("/note/v1/share-groups/{groupId}/members")
    public ResponseEntity<Map<String, Object>> removeMember(@PathVariable Long groupId,
                                                            @RequestParam("memberId") String targetMemberId) {
        String memberId = SecurityUtils.getCurrentUserLogin().orElse(null);
        if (memberId == null) return unauthorized();
        boolean ok = groupService.removeMember(memberId, groupId, targetMemberId);
        if (!ok) return badRequest("멤버를 찾을 수 없습니다.");
        return ok(Map.of("message", "제거 완료"));
    }

    // ── 헬퍼 ──
    private ResponseEntity<Map<String, Object>> ok(Map<String, Object> data) {
        Map<String, Object> result = new HashMap<>(data);
        result.put("success", true);
        return ResponseEntity.ok(result);
    }

    private ResponseEntity<Map<String, Object>> unauthorized() {
        return ResponseEntity.status(401).body(Map.of("success", false, "message", "로그인이 필요합니다."));
    }

    private ResponseEntity<Map<String, Object>> badRequest(String message) {
        return ResponseEntity.badRequest().body(Map.of("success", false, "message", message));
    }
}
