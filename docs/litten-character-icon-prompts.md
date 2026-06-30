# 리튼(Litten) 캐릭터·아이콘 생성 프롬프트 가이드

이미지 생성 AI(GPT-4o 이미지 / DALL·E 3 / Midjourney / Stable Diffusion 등)에 넣어
리튼 마스코트 캐릭터와 앱 아이콘을 만들기 위한 프롬프트 모음입니다.

---

## 0. 먼저 "리튼이 어떤 앱인지" 설명부터 (이미지 AI에 컨텍스트 깔기)

대화형 이미지 생성(GPT-4o 이미지 · Gemini 등)에서는 아래 소개문을 **먼저 붙여넣어 맥락을 깔고**,
그 다음에 "이 앱의 마스코트/아이콘을 만들어줘 + (해당 프롬프트)"를 이어서 요청하세요.
훨씬 콘셉트에 맞는 결과가 나옵니다.

### 짧은 소개 (한글)
```
리튼(Litten)은 'Listen(듣기) + Write(쓰기)'를 합친 이름의 올인원 노트 앱이야.
하나의 공간에서 ① 음성 녹음·받아쓰기(STT), ② 텍스트 작성, ③ 이미지·PDF 위 필기를 하고,
④ AI가 그 기록을 자동으로 요약하고 학습 퀴즈까지 만들어줘.
30개 언어를 지원하는 친근하고 깔끔한 모바일 앱이고,
브랜드 색은 차분한 블루(#4A90E2), AI를 상징하는 골드 반짝임(#FBBF24)이 포인트야.
```

### 짧은 소개 (영문)
```
Litten (from "Listen + Write") is an all-in-one note-taking app. In a single space you can
(1) record audio with speech-to-text, (2) write text notes, and (3) draw/annotate on images and PDFs,
and (4) its AI automatically summarizes your notes and even generates study quizzes.
It's a friendly, clean mobile app supporting 30 languages.
Brand colors: calm blue (#4A90E2) with a gold AI sparkle accent (#FBBF24).
```

### 한 줄 태그라인
```
"듣고, 쓰고, 그리고, AI로 정리하다" — Listen, Write, and let AI organize it.
```

> 사용 예: 위 소개문 붙여넣기 → 줄바꿈 → "이 앱의 마스코트 캐릭터를 만들어줘. (3-1 프롬프트)"

---

## 0.5. 브랜드 DNA (모든 프롬프트에 깔고 가는 토대)

| 항목 | 값 |
|------|----|
| 이름 뜻 | Litten = **Listen + Write** (듣기 + 쓰기) |
| 정체성 | 듣기(녹음·STT) · 쓰기(텍스트) · 필기(드로잉) · **AI 요약/퀴즈**를 합친 노트 앱 |
| 메인 컬러 | 블루 그라데이션 `#4A90E2 → #357ABD` |
| 포인트 컬러 | 골드/앰버 `#FBBF24` (AI·반짝임 상징) |
| 무드 | 친근함, 깔끔함, 모던, 미니멀, 신뢰감 |
| 상징 소품 | 노트/문서, 텍스트 줄, 연필, 헤드폰/음파, ✨스파클 |

> 핵심 메시지: **"기록을 AI가 똑똑하게 정리해준다"** → 노트 + 반짝임(AI) 조합이 가장 리튼답습니다.

---

## 1. 프롬프트 작성 공식

```
[유형] + [주체/콘셉트] + [핵심 특징·소품] + [스타일] + [색상] + [배경] + [용도/포맷] + [제외할 것]
```

예) `앱 아이콘` + `둥근 노트` + `텍스트 줄 + AI 스파클` + `플랫 미니멀 벡터` + `블루 그라데이션 + 골드` + `흰 배경` + `iOS 아이콘, 글자 없음` + `(사진풍 제외)`

---

## 2. 앱 아이콘 프롬프트

### 2-1. 현재 디자인을 그대로 고급화 (추천 출발점)
**영문 (Midjourney/DALL·E)**
```
App icon for a note-taking app named "Litten". A rounded-corner notebook/document
with three horizontal text lines inside, and a small four-point sparkle in the top-right
corner representing AI. Blue gradient (#4A90E2 to #357ABD) document, white text lines,
gold (#FBBF24) sparkle. Flat minimal vector style, soft long shadow, iOS app icon,
centered, clean white background, no text, no letters. --ar 1:1 --v 6
```
**한글 (GPT-4o 이미지)**
```
"리튼"이라는 노트 앱의 아이콘을 만들어줘. 둥근 모서리의 노트(문서) 안에 가로 텍스트 줄 3개가 있고,
오른쪽 위에 AI를 상징하는 작은 4각 반짝임(스파클)이 얹혀 있어. 노트는 파란색 그라데이션(#4A90E2→#357ABD),
텍스트 줄은 흰색, 스파클은 골드(#FBBF24). 플랫하고 미니멀한 벡터 스타일, iOS 앱 아이콘, 가운데 정렬,
흰 배경, 글자 없음.
```

### 2-2. "듣기 + AI" 강조 (음파 버전)
```
Minimal app icon for "Litten": a speech/sound wave morphing into text lines,
with a gold AI sparkle. Blue gradient background, rounded squircle, flat vector,
modern, simple, no text. --ar 1:1 --v 6
```

### 2-3. 모노그램 'L' 버전
```
App icon: a clean monogram letter "L" formed by a folded notebook page,
with a tiny gold sparkle dot. Blue gradient, flat minimal vector, squircle,
white background, no extra text. --ar 1:1 --v 6
```

---

## 3. 마스코트 캐릭터 프롬프트

### 3-1. 노트 의인화 (가장 직관적)
**영문**
```
Cute mascot character for an app called "Litten". A friendly anthropomorphic notebook
with big round eyes and a gentle smile, wearing small headphones, holding a pencil.
A little gold sparkle floating above its head (AI). Soft rounded shapes, kawaii flat
illustration, thick clean outlines, blue and white color palette with gold accent,
full body, simple white background, vector style, mascot logo. --ar 1:1 --v 6
```
**한글**
```
"리튼" 앱의 귀여운 마스코트 캐릭터를 만들어줘. 친근하게 의인화된 노트(공책) 캐릭터로,
큰 동그란 눈과 부드러운 미소, 작은 헤드폰을 끼고 연필을 들고 있어. 머리 위에 AI를 뜻하는
작은 골드 반짝임이 떠 있어. 둥글둥글하고 깔끔한 외곽선, 카와이 플랫 일러스트,
파랑+흰색에 골드 포인트, 전신, 흰 배경, 벡터 스타일의 마스코트.
```

### 3-2. 말풍선/음파 생물형
```
Mascot for "Litten": a cute round blob character shaped like a speech bubble,
with headphones and tiny arms holding a pen, a gold AI sparkle nearby. Friendly,
minimal, flat vector, blue palette with gold accent, white background. --ar 1:1 --v 6
```

### 3-3. 마스코트 표정/포즈 시트 (캐릭터 확정 후)
```
Character expression sheet for the Litten notebook mascot: 6 poses and emotions
(happy, thinking, listening, writing, surprised, sleeping), consistent design,
flat vector, blue and gold palette, white background. --ar 16:9 --v 6
```

---

## 4. 도구별 사용 팁

- **GPT-4o 이미지 / DALL·E 3**: 자연어 문장형이 잘 먹힙니다. **한글 프롬프트도 OK**. "글자(텍스트)는 넣지 말 것"을 꼭 명시(아이콘에 깨진 글자가 자주 들어감).
- **Midjourney**: 끝에 파라미터 → `--ar 1:1`(정사각), `--v 6`, 더 그래픽한 느낌은 `--style raw`. 로고/플랫은 `vector, flat` 키워드가 중요.
- **Stable Diffusion**: 키워드 나열형 + 아래 네거티브 프롬프트 병행. `flat vector, mascot logo, simple` 등 강조.

### 네거티브 프롬프트 (SD / 품질 보정)
```
text, words, letters, watermark, signature, blurry, low quality, jpeg artifacts,
realistic photo, 3d render, cluttered, busy background, extra limbs, deformed,
gradient mesh noise
```

---

## 5. 색상 레퍼런스 (프롬프트에 그대로 복붙)

```
Primary blue: #4A90E2
Dark blue:    #357ABD
Light blue:   #6BB6FF
Gold accent:  #FBBF24
Ink/text:     #1E293B
Background:   #FFFFFF
```

---

## 6. 활용 순서 추천

1. **2-1**(아이콘) 또는 **3-1**(마스코트)로 시안 4~8장 생성
2. 마음에 드는 1장 선택 → "이 스타일 유지하고 ○○만 바꿔줘"로 변형(variation)
3. 캐릭터가 확정되면 **3-3**(표정 시트)로 여러 포즈 확보
4. 최종 PNG/SVG 정리 후, 앱 런처 아이콘·스플래시·홈페이지에 적용

> 생성된 이미지를 주시면, 배경 제거·색 보정·SVG 변환·앱 아이콘 사이즈(android mipmap / iOS AppIcon) 일괄 생성까지 도와드릴 수 있습니다.
