package com.litten.common.dynamic;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Data;
import org.springframework.http.HttpStatus;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Objects;

@Data
@SuppressWarnings("unchecked")
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ResponseVo {
	/*
		■ HTTP Status 기본 코드
		- 200 OK                    : 성공
		- 204 No Content            : 데이터 없음
		- 400 Bad Request           : 잘못된 요청
		- 401 Unauthorized          : 인증실패
		- 403 Forbidden             : 권한없음
		- 404 Not Found             : 요청 URL 없음
		- 405 Method Not Allowed    : 제한된 메소드 요청
		- 409 Conflict              : 리소스 충돌
		- 423 Locked                : 토큰 만료
		- 500 Internal Server Error : 내부 서버 에러
	*/
	private int status;     // HTTP Status 코드
	private String message; // HTTP Status 메시지
	private Map<String, Object> body;

	private int result;

	private List<Object> listBody;
//	private LocalDateTime timestamp = LocalDateTime.now();
	private final OffsetDateTime timestamp = OffsetDateTime.now();

	private void setDefaultMsg(int status){

		this.status     = status;
		this.message    = Objects.requireNonNull(HttpStatus.resolve(status)).getReasonPhrase();
	}

	public ResponseVo(int status) {

		this.setDefaultMsg(status);
	}

	// map setBody
	public ResponseVo(int status, Map<String, Object> body) {

		this.setDefaultMsg(status);
		this.body   = body;
	}
	// object setBody
	public ResponseVo(int status, Object body) {

		ObjectMapper objectMapper   = new ObjectMapper();
		Map<String, Object> mapBody = objectMapper.convertValue(body, Map.class);

		this.setDefaultMsg(status);
		this.body   = mapBody;
	}

	public ResponseVo(int status, String message) {

		this.status     = status;
		this.message    = message;
	}

	// map setBody
	public ResponseVo(int status, String message, Map<String, Object> body) {

		this.status     = status;
		this.message    = message;
		this.body       = body;
	}
	// object setBody
	public ResponseVo(int status, String message, Object body) {

		ObjectMapper objectMapper   = new ObjectMapper();
		Map<String, Object> mapBody = objectMapper.convertValue(body, Map.class);

		this.status     = status;
		this.message    = message;
		this.body       = mapBody;
	}

	public ResponseVo(int status, List<Object> listBody) {
		this.status		= status;
		this.listBody	= listBody;
	}

	public ResponseVo(int status, int result) {
		this.status		= status;
		this.result		= result;
	}
}
