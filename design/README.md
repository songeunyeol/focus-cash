# 디자인 작업 파일

## home-redesign-mockup.html
홈·기록 화면 리디자인 목업. Pretendard 서브셋(120KB)이 인라인돼 있어 파일 하나로 열린다.
브라우저로 바로 열어 확인 가능. 아티팩트 배포본: https://claude.ai/code/artifact/9ad29a7b-64ca-48e9-bb36-752e844edb08

목업으로 먼저 확정하고 Flutter 로 옮기는 이유: 빌드가 3~14분 걸려서 레이아웃 탐색에 쓰기엔 너무 느리다.

## icon-gen/
앱 아이콘(웜 불꽃) 생성 스크립트와 초안. `python gen.py` 로 재생성.
링 두께·불꽃 크기·기울기·개구부 각도가 전부 상수로 빠져 있다.

- `icon_draft.png` 1024x1024 (앱에 아직 미적용)
- `preview_sheet.png` 런처 실제 크기 192/96/48px 대조

현재 앱 아이콘은 14차의 쿨 계열(시안+퍼플)이라 웜 액센트와 어긋난 상태다.
교체 시 `assets/icon/icon.png` 덮어쓰고 `flutter pub run flutter_launcher_icons` 재생성.
