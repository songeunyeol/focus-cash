from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, PageBreak
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
import os

# Register a Unicode font for Korean text
# Try to use a system font that supports Korean
FONT_PATHS = [
    "C:/Windows/Fonts/malgun.ttf",       # Malgun Gothic (Windows default Korean)
    "C:/Windows/Fonts/NanumGothic.ttf",
    "C:/Windows/Fonts/gulim.ttc",
]

font_name = "Malgun"
font_registered = False
for path in FONT_PATHS:
    if os.path.exists(path):
        try:
            pdfmetrics.registerFont(TTFont(font_name, path))
            font_registered = True
            print(f"Using font: {path}")
            break
        except Exception as e:
            print(f"Failed {path}: {e}")

if not font_registered:
    font_name = "Helvetica"
    print("No Korean font found, using Helvetica (Korean may not render)")

# Colors
PRIMARY = colors.HexColor("#6C5CE7")
SECONDARY = colors.HexColor("#FFA502")
DARK_BG = colors.HexColor("#1A1A2E")
ACCENT_GREEN = colors.HexColor("#00D2D3")
CREDIT_GOLD = colors.HexColor("#FFD700")
DARK_GRAY = colors.HexColor("#2D2D2D")
LIGHT_GRAY = colors.HexColor("#F5F5F5")
TEXT_GRAY = colors.HexColor("#555555")

# Styles
styles = getSampleStyleSheet()

def s(name, **kwargs):
    base = kwargs.pop("parent", "Normal")
    return ParagraphStyle(name, parent=styles[base], fontName=font_name, **kwargs)

style_title = s("Title",
    fontSize=28, textColor=PRIMARY, spaceAfter=6,
    spaceBefore=0, alignment=TA_CENTER, leading=36)

style_subtitle = s("SubTitle",
    fontSize=14, textColor=TEXT_GRAY, spaceAfter=20,
    alignment=TA_CENTER)

style_h1 = s("H1",
    fontSize=18, textColor=PRIMARY, spaceBefore=16, spaceAfter=8,
    leading=24, borderPad=4)

style_h2 = s("H2",
    fontSize=14, textColor=SECONDARY, spaceBefore=12, spaceAfter=6,
    leading=20)

style_h3 = s("H3",
    fontSize=12, textColor=colors.HexColor("#6C5CE7"),
    spaceBefore=8, spaceAfter=4, leading=18)

style_body = s("Body",
    fontSize=10, textColor=colors.black, spaceAfter=4,
    leading=16)

style_bullet = s("Bullet",
    fontSize=10, textColor=TEXT_GRAY, spaceAfter=3,
    leftIndent=12, leading=15)

style_cell = s("Cell",
    fontSize=9, textColor=colors.black, leading=13)

style_cell_header = s("CellHeader",
    fontSize=9, textColor=colors.white,
    leading=13)

style_caption = s("Caption",
    fontSize=9, textColor=TEXT_GRAY, spaceAfter=12,
    alignment=TA_CENTER, italic=True)

def h1(text):
    return [
        HRFlowable(width="100%", thickness=2, color=PRIMARY, spaceAfter=4),
        Paragraph(text, style_h1),
    ]

def h2(text):
    return [Paragraph(text, style_h2)]

def h3(text):
    return [Paragraph(text, style_h3)]

def body(text):
    return Paragraph(text, style_body)

def bullet(text):
    return Paragraph(f"• {text}", style_bullet)

def spacer(h=6):
    return Spacer(1, h * mm)

def table(data, col_widths=None, header_bg=PRIMARY):
    t = Table(data, colWidths=col_widths, repeatRows=1)
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), header_bg),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, -1), font_name),
        ("FONTSIZE", (0, 0), (-1, 0), 9),
        ("FONTSIZE", (0, 1), (-1, -1), 9),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CCCCCC")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1),
         [colors.white, colors.HexColor("#F9F9F9")]),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]
    t.setStyle(TableStyle(style))
    return t


# ─── Content ──────────────────────────────────────────────────────────────────

content = []

# Cover
content += [
    spacer(20),
    Paragraph("포커스 캐시", style_title),
    Paragraph("Focus Cash", s("En", fontSize=16, textColor=TEXT_GRAY,
                              alignment=TA_CENTER, spaceAfter=4)),
    Paragraph("종합 기획 · 개발 · 사업 계획서", style_subtitle),
    spacer(4),
    HRFlowable(width="60%", thickness=3, color=SECONDARY,
               hAlign="CENTER", spaceAfter=16),
    Paragraph("집중하면 돈이 되는 시간", s("Tag",
        fontSize=18, textColor=SECONDARY, alignment=TA_CENTER, spaceAfter=6)),
    spacer(4),
    Paragraph(
        "크로스플랫폼(Flutter) · Android &amp; iOS 동시 출시",
        s("Platform", fontSize=11, textColor=TEXT_GRAY, alignment=TA_CENTER)),
    spacer(30),
    PageBreak(),
]

# ── PART 1: 기획서 ─────────────────────────────────────────────────────────────
content += h1("Part 1. 보완된 기획서")
content.append(spacer())

# 1.1 UI/UX
content += h2("1.1 UI/UX 상세 화면 설계")
content += h3("A. 온보딩 플로우")
content += [
    bullet("앱 설치 → 권한 요청(알림, 사용정보 접근) → 목표 설정 → 첫 집중 시작"),
    spacer(3),
]

content += h3("B. 주요 화면 구성")
screens_data = [
    ["화면", "핵심 구성 요소"],
    ["메인 홈", "오늘의 집중 시간 / 크레딧 잔액 / 랭킹 미리보기 / 빠른 시작"],
    ["집중(잠금)", "다크 배경 + 타이머 카운트다운 + 배너 광고 + 긴급 해제 버튼"],
    ["상점", "확정 교환 / 룰렛 / 응모방 3개 탭"],
    ["랭킹", "일간/주간/월간 + 전체/친구 필터"],
    ["프로필", "집중 통계 / 크레딧 내역 / 설정"],
]
content.append(table(screens_data, col_widths=[50*mm, 120*mm]))
content.append(spacer())

# 1.2 User Journey
content += h2("1.2 사용자 시나리오 (User Journey)")
journey = [
    ("STEP 1", "사용자가 '2시간 집중' 선택 → 전면 광고 1회 시청 (시작 시점)"),
    ("STEP 2", "집중 화면 진입 → 다크 배너 광고 하단 노출"),
    ("STEP 3", "1시간 경과 → '집중 중이신가요?' 팝업 → 스와이프 확인"),
    ("STEP 4", "2시간 완료 → 전면 광고 1회 시청 (종료 시점) → 크레딧 지급"),
    ("STEP 5", "상점에서 크레딧 사용 (교환 / 룰렛 / 응모방)"),
]
for step, desc in journey:
    content.append(body(f"<b><font color='#6C5CE7'>{step}</font></b>  {desc}"))
content.append(spacer())

# 1.3 크레딧 경제
content += h2("1.3 크레딧 경제 상세 설계")
credit_data = [
    ["항목", "수치"],
    ["집중 10분당 기본 크레딧", "50 크레딧"],
    ["시작 광고 시청 보너스", "+30 크레딧"],
    ["종료 광고 시청 보너스", "+30 크레딧"],
    ["1시간 집중 총 획득", "약 360 크레딧"],
    ["일일 획득 한도 (Daily Cap)", "3,000 크레딧 (~8시간 집중)"],
    ["커피 쿠폰 교환", "10,000 크레딧 (약 3~4일 성실 사용)"],
    ["룰렛 1회", "100 크레딧"],
    ["응모 1회", "500 크레딧"],
]
content.append(table(credit_data, col_widths=[100*mm, 70*mm]))
content.append(spacer())

# 1.4 어뷰징
content += h2("1.4 어뷰징 방지 상세 정책")
for t_ in [
    "집중 확인 팝업: 30~90분 랜덤 간격, 1분 내 미응답 시 타이머 일시정지",
    "가속도 센서 체크: 기기 완전 정지 상태(방치 의심) 시 추가 확인 요청",
    "일일 한도: 3,000 크레딧/일",
    "비정상 패턴 감지: 매일 정확히 같은 시간에 최대 한도 달성 → 경고",
    "디바이스 중복 방지: 1인 1계정 (전화번호 인증)",
]:
    content.append(bullet(t_))
content.append(spacer())

# 1.5 하드코어
content += h2("1.5 하드코어 모드 상세")
hardcore_data = [
    ["모드", "패널티", "추가 조건"],
    ["일반 모드 (기본)", "이탈 시 진행 크레딧만 소멸", "—"],
    ["하드코어 모드 (선택)", "이탈 시 보유 크레딧 10% 추가 차감", "—"],
    ["울트라 모드 (선택)", "이탈 시 보유 크레딧 차감", "친구에게 알림 발송"],
    ["공통", "—", "'정말 포기?' 팝업 → 광고 시청 시 1회 용서"],
]
content.append(table(hardcore_data, col_widths=[50*mm, 80*mm, 50*mm]))
content.append(spacer())

# 1.6 추가 기능
content += h2("1.6 추가 보완 기능")
content += h3("F. 학습 기록 및 통계")
for t_ in ["일/주/월별 집중 시간 그래프", "과목별 태그 기능 (수학, 영어 등)", "연속 집중 스트릭(streak) 시스템"]:
    content.append(bullet(t_))

content += h3("G. 푸시 알림 전략")
for t_ in ["매일 설정 시간에 '오늘 목표 시간 리마인더'",
           "친구가 집중 시작했을 때 'OO님이 공부 시작했어요'",
           "응모방 마감 임박 알림", "랭킹 변동 알림"]:
    content.append(bullet(t_))

content += h3("H. 프리미엄(구독) 모델")
content.append(bullet("월 3,900원 구독: 광고 제거 + 크레딧 2배 적립 + 상세 통계"))
content.append(bullet("광고 수익 감소분을 구독료로 보전하는 하이브리드 모델"))
content.append(spacer())
content.append(PageBreak())

# ── PART 2: 개발 ────────────────────────────────────────────────────────────────
content += h1("Part 2. 개발 구현 계획")
content.append(spacer())

content += h2("2.1 기술 스택 (크로스플랫폼)")
tech_data = [
    ["영역", "기술", "선택 이유"],
    ["프론트엔드", "Flutter (Dart)", "네이티브 성능, 풍부한 UI 커스터마이징"],
    ["백엔드", "Firebase (Firestore + Functions)", "빠른 MVP, 실시간 DB, 인증, 푸시 통합"],
    ["인증", "Firebase Auth (전화번호+소셜)", "한국 시장 전화번호 인증"],
    ["광고", "Google AdMob + Cauly", "한국 시장 eCPM 최적화, 미디에이션"],
    ["결제", "Play Billing / Apple IAP", "프리미엄 구독"],
    ["푸시", "Firebase Cloud Messaging", "크로스플랫폼 푸시"],
    ["분석", "Firebase Analytics + Crashlytics", "사용자 행동 분석 및 크래시 추적"],
    ["CI/CD", "GitHub Actions + Codemagic", "Flutter 빌드 자동화"],
]
content.append(table(tech_data, col_widths=[35*mm, 60*mm, 75*mm]))
content.append(spacer())

content += h2("2.2 핵심 아키텍처")
content.append(body(
    "<b>Flutter App</b><br/>"
    "├── 집중 타이머 (Foreground Service / iOS Background Mode)<br/>"
    "├── 광고 모듈 (AdMob + Mediation)<br/>"
    "├── 잠금 화면 UI (Overlay / Full-screen Activity)<br/>"
    "└── 로컬 알림 (집중 확인 팝업)<br/><br/>"
    "<b>Firebase Backend</b><br/>"
    "├── Firestore: 사용자, 크레딧, 집중기록, 응모방<br/>"
    "├── Cloud Functions: 크레딧 계산, 응모 추첨, 어뷰징 감지<br/>"
    "├── Auth: 전화번호/소셜 로그인<br/>"
    "└── FCM: 푸시 알림"
))
content.append(spacer())

content += h2("2.3 플랫폼별 기술 이슈 및 해결")
platform_data = [
    ["이슈", "Android", "iOS"],
    ["스마트폰 잠금",
     "Foreground Service + SYSTEM_ALERT_WINDOW",
     "앱 내부 전체화면 유지, 이탈 시 타이머 종료 (Forest 방식)"],
    ["다른 앱 감지",
     "UsageStatsManager로 앱 전환 감지",
     "AppDelegate lifecycle으로 백그라운드 전환 감지"],
    ["배터리 최적화",
     "배터리 최적화 예외 요청",
     "Background Mode 최소화"],
]
content.append(table(platform_data, col_widths=[35*mm, 80*mm, 55*mm]))
content.append(spacer())

content += h2("2.4 개발 단계별 태스크")
phases = [
    ("Phase 1: MVP (6주)", [
        "프로젝트 셋업 (Flutter + Firebase)",
        "회원가입/로그인 (전화번호 인증)",
        "집중 타이머 핵심 기능 (시작/종료/포기)",
        "집중 화면 UI (타이머 + 다크 모드)",
        "기본 크레딧 적립 시스템",
        "AdMob 배너 + 전면 광고 연동",
        "크레딧 확정 교환 (기프티콘 API 연동)",
    ]),
    ("Phase 2: 게이미피케이션 (4주)", [
        "룰렛 시스템", "응모방 (크라우드 로또) 시스템",
        "집중 확인 팝업 (어뷰징 방지)", "일일 한도 시스템",
        "하드코어 모드", "집중 통계 대시보드",
    ]),
    ("Phase 3: 소셜 (3주)", [
        "전국 타이머 랭킹", "친구 추가 / 그룹 스터디방",
        "친구 실시간 접속 상태", "푸시 알림 시스템",
    ]),
    ("Phase 4: 수익 최적화 (2주)", [
        "프리미엄 구독 모델", "광고 미디에이션 최적화",
        "A/B 테스트 프레임워크", "리텐션 분석 및 이벤트 추적",
    ]),
    ("Phase 5: 출시 준비 (2주)", [
        "QA 및 버그 수정", "스토어 등록 자료 (스크린샷, 설명문)",
        "개인정보 처리방침 / 이용약관",
        "구글 플레이 + 앱스토어 심사 제출",
    ]),
]
for phase_title, tasks in phases:
    content += h3(f"✓ {phase_title}")
    for task in tasks:
        content.append(bullet(f"[  ] {task}"))
    content.append(spacer(3))

content.append(body("<b>총 예상 기간: 약 17주 (4개월)</b>"))
content.append(PageBreak())

# ── PART 3: 사업 ────────────────────────────────────────────────────────────────
content += h1("Part 3. 사업 계획")
content.append(spacer())

content += h2("3.1 시장 분석")
content.append(body("<b>타겟 시장</b>: 한국 Z세대 수험생 + 대학생 (약 800만명)"))
market_data = [
    ["타겟 세그먼트", "규모"],
    ["수능 수험생", "~50만명/년"],
    ["대학생", "~300만명"],
    ["고시/공시 준비생", "~50만명"],
    ["자기계발 직장인", "~400만명"],
]
content.append(table(market_data, col_widths=[90*mm, 80*mm]))
content.append(spacer())

content += h2("경쟁사 분석")
comp_data = [
    ["앱", "강점", "약점", "포커스캐시 차별점"],
    ["Forest", "글로벌 인지도, 나무 심기 감성", "금전적 보상 없음", "실질적 크레딧 보상"],
    ["열품타", "한국 수험생 커뮤니티", "보상 없음, 구시대적 UI", "리워드 + 모던 UI"],
    ["캐시워크", "검증된 리워드 모델", "걷기 특화, 공부 무관", "공부 집중 특화"],
]
content.append(table(comp_data, col_widths=[25*mm, 52*mm, 50*mm, 45*mm]))
content.append(spacer())

content += h2("3.2 수익 모델 시뮬레이션 (DAU 10,000명 기준)")
rev_data = [
    ["광고 유형", "노출 수/일", "eCPM", "일 매출"],
    ["배너 (집중 중)", "120,000회", "$1.5", "$180"],
    ["전면 (시작+종료)", "20,000회", "$8", "$160"],
    ["리워디드 (용서 광고 등)", "3,000회", "$15", "$45"],
    ["합계", "—", "—", "$385/일"],
]
content.append(table(rev_data, col_widths=[50*mm, 45*mm, 30*mm, 45*mm]))
content.append(spacer(3))
content.append(body(
    "<b>월 매출:</b> 약 $11,550 (약 1,500만원) &nbsp;|&nbsp; "
    "<b>크레딧 환원율 30%:</b> 약 450만원 &nbsp;|&nbsp; "
    "<b>운영비 20%:</b> 약 300만원 &nbsp;|&nbsp; "
    "<b>순수익:</b> 약 750만원/월"
))
content.append(spacer())

content += h2("3.3 마케팅 전략")
content += h3("런칭 전 (D-30)")
for t_ in ["수능 커뮤니티 (오르비, 수만휘) 바이럴 시딩",
           "에브리타임(대학생 커뮤니티) 홍보",
           "인스타그램/틱톡 스터디 인플루언서 협업 (3~5명)"]:
    content.append(bullet(t_))

content += h3("런칭 후 (D-Day ~ D+90)")
for t_ in ["'공부하면 커피 준다' 핵심 메시지",
           "첫 가입 시 1,000 크레딧 즉시 지급",
           "친구 초대 시 양측 500 크레딧",
           "응모방 초기 이벤트: 에어팟 응모방 (낮은 진입 크레딧)"]:
    content.append(bullet(t_))

content += h3("성장기 (D+90~)")
for t_ in ["수능 시즌 집중 마케팅 (9~11월)",
           "기말고사 시즌 캠페인 (6월, 12월)",
           "스터디 카페 / 학원 제휴"]:
    content.append(bullet(t_))
content.append(spacer())

content += h2("3.4 법적 고려사항")
legal_data = [
    ["항목", "내용", "대응"],
    ["확률형 아이템 (룰렛)", "게임산업진흥법상 확률 공개 의무", "룰렛 확률표 앱 내 상시 공개"],
    ["응모형 (크라우드 로또)", "사행성 규제 검토 필요",
     "크레딧은 앱 내 포인트로 설계, 법률 자문 필수"],
    ["개인정보보호법 (PIPA)", "전화번호, 사용 패턴 수집",
     "개인정보 처리방침 작성, 최소 수집 원칙"],
    ["청소년 보호", "미성년 타겟 앱",
     "확률형 소비 월 한도 설정, 법정대리인 동의"],
]
content.append(table(legal_data, col_widths=[40*mm, 65*mm, 65*mm]))
content.append(spacer())

content += h2("3.5 KPI 목표")
kpi_data = [
    ["시기", "DAU", "MAU", "월 매출"],
    ["출시 1개월", "1,000", "5,000", "150만원"],
    ["출시 3개월", "5,000", "20,000", "750만원"],
    ["출시 6개월", "15,000", "60,000", "2,250만원"],
    ["출시 12개월", "30,000", "120,000", "4,500만원"],
]
content.append(table(kpi_data, col_widths=[45*mm, 40*mm, 40*mm, 45*mm]))
content.append(PageBreak())

# ── PART 4: 검증 ────────────────────────────────────────────────────────────────
content += h1("Part 4. 검증 방법")
content.append(spacer())
validations = [
    ("기획 검증", "타겟 사용자 10명 인터뷰 + 프로토타입(Figma) 테스트"),
    ("기술 검증", "Flutter로 타이머 + 잠금화면 + AdMob PoC 2주 내 구현"),
    ("수익 검증", "MVP 출시 후 30일간 eCPM 실측치 vs 예상치 비교"),
    ("시장 검증", "첫 달 자연 유입 + 바이럴 계수(K-factor) 측정"),
]
for title, desc in validations:
    content.append(body(f"<b><font color='#6C5CE7'>▶ {title}</font></b>"))
    content.append(body(f"&nbsp;&nbsp;&nbsp;{desc}"))
    content.append(spacer(3))

content.append(PageBreak())

# ── PART 5: 개발 현황 ──────────────────────────────────────────────────────────
content += h1("Part 5. 개발 현황 및 다음 단계 (2026-03-09 기준)")
content.append(spacer())

content += h2("5.1 완성도 현황표")
status_data = [
    ["영역", "완성도", "상태"],
    ["인증 (로그인 / 데모 모드)", "95%", "✅ 완료"],
    ["집중 타이머 (확인팝업 / 어뷰징 방지 포함)", "98%", "✅ 완료"],
    ["크레딧 적립 / 차감 시스템", "90%", "✅ 완료"],
    ["프로필 / 집중 통계 화면", "95%", "✅ 완료"],
    ["상점 — 교환 탭 (기프티콘)", "90%", "✅ 완료"],
    ["상점 — 룰렛 탭 (확률표 포함)", "90%", "✅ 완료"],
    ["상점 — 응모방 탭 (참여/완료/종료 상태)", "85%", "✅ 완료"],
    ["주간 차트 실시간 데이터 연동", "80%", "✅ 완료"],
    ["배포 전 클린업 (테스트버튼 제거, 빈메뉴 처리)", "100%", "✅ 완료"],
    ["랭킹 시스템 실데이터 연동", "10%", "❌ 미완"],
    ["Firebase 실제 프로젝트 연동", "0%", "❌ 미완"],
    ["푸시 알림 시스템", "0%", "❌ 미완"],
    ["프리미엄 구독 결제", "0%", "❌ 미완"],
    ["스토어 출시 준비", "0%", "❌ 미완"],
]
content.append(table(status_data, col_widths=[90*mm, 30*mm, 50*mm]))
content.append(spacer())

content += h2("5.2 이번 세션에서 완료된 작업 (2026-03-09)")

content += h3("① 상점 응모방 탭 — 완전 구현")
for t_ in [
    "응모방 목록 4개 (진행중 3개 + 종료 1개) 표시",
    "_enteredRooms: Set<int> 로컬 상태로 참여 방 추적",
    "응모 버튼 클릭 → 크레딧 부족 사전 체크 → 확인 다이얼로그 → creditService.spendCredits() 호출",
    "참여 완료 상태: 초록 체크 배지로 전환",
    "종료된 방: '응모 종료' 표시 + 당첨자 이름 (골드 트로피 아이콘)",
    "진행률 바: 80% 초과 시 빨간색으로 긴박감 표시",
]:
    content.append(bullet(t_))
content.append(spacer(3))

content += h3("② 주간 차트 실시간 데이터 연동")
for t_ in [
    "WeeklyChart 위젯에 List<int>? data 파라미터 추가 (null이면 모두 0으로 초기화)",
    "_buildWeeklyData(todayMinutes): DateTime.now().weekday - 1 로 오늘 요일 인덱스 계산",
    "홈 화면 / 집중 통계 화면 양쪽에서 user.todayFocusMinutes 실시간 주입",
    "집중 세션 완료 직후 오늘 칸이 즉시 업데이트됨",
]:
    content.append(bullet(t_))
content.append(spacer(3))

content += h3("③ 배포 전 클린업")
for t_ in [
    "focus_screen.dart: '[테스트] 즉시 완료' 버튼 완전 제거",
    "profile_screen.dart: 알림 설정 / 프리미엄 구독 / 개인정보처리방침 / 이용약관 → '준비 중' 스낵바 표시",
]:
    content.append(bullet(t_))
content.append(spacer())

content += h2("5.3 다음 단계 — 우선순위별 작업 목록")

next_steps = [
    ("🔴 P0 — Firebase 실제 연동 (출시 필수)", [
        "Firebase 콘솔에서 새 프로젝트 생성 (Android + iOS 앱 등록)",
        "flutterfire configure 로 google-services.json / GoogleService-Info.plist 자동 생성",
        "전화번호 인증 실제 테스트 (현재 데모 모드로만 동작)",
        "Firestore 보안 규칙 설정 (사용자 데이터 격리)",
        "Cloud Functions: 크레딧 계산 서버사이드 검증 (클라이언트 신뢰 제거)",
    ]),
    ("🔴 P0 — AdMob 실제 광고 ID 적용", [
        "AdMob 계정 생성 및 앱 등록",
        "테스트 광고 ID → 실제 광고 단위 ID로 교체",
        "배너 광고 / 전면 광고 / 리워디드 광고 각각 테스트",
        "앱 출시 최소 2주 전에 AdMob 검토 제출",
    ]),
    ("🟡 P1 — 랭킹 시스템 실데이터 연동", [
        "ranking_screen.dart: 현재 Mock 데이터 → Firestore 실데이터 조회로 전환",
        "일간 / 주간 / 월간 집중 시간 집계 (Firestore 쿼리 or Cloud Functions)",
        "자신의 순위 강조 표시 로직 구현",
        "랭킹 업데이트 주기 결정 (실시간 vs 1시간마다)",
    ]),
    ("🟡 P1 — 주간 데이터 영속화", [
        "UserModel에 weeklyFocusMinutes: List<int> 필드 추가 (7개 요일)",
        "FocusProvider 세션 완료 시 해당 요일 인덱스에 누적 저장",
        "자정 리셋 로직 (날짜 변경 감지 → 오늘 칸 초기화, 내일 칸으로 이동)",
        "Firestore에 주간 데이터 동기화",
    ]),
    ("🟡 P1 — 응모방 서버사이드 추첨", [
        "Firestore에 raffle_rooms 컬렉션 구성",
        "Cloud Functions: 마감 시간 도달 시 자동 추첨 실행",
        "당첨자 알림 (FCM 푸시)",
        "참여자 수 실시간 업데이트 (Firestore 리스너)",
    ]),
    ("🟢 P2 — 푸시 알림 시스템", [
        "FCM 토큰 저장 (로그인 시 Firestore에 등록)",
        "목표 시간 리마인더 알림 (로컬 알림으로 구현 가능)",
        "응모방 마감 임박 알림 (D-1, 12시간 전)",
        "스트릭 유지 알림 (어제 집중했는데 오늘 아직 시작 안 한 경우)",
    ]),
    ("🟢 P2 — 프리미엄 구독 결제", [
        "Google Play Billing / Apple IAP 연동",
        "월 3,900원 구독: 광고 제거 + 크레딧 2배 적립",
        "구독 상태 Firestore 동기화 (영수증 검증은 서버사이드)",
        "무료 체험 7일 플로우",
    ]),
    ("🟢 P2 — 스토어 출시 준비", [
        "앱 아이콘 / 스플래시 화면 최종 디자인",
        "스크린샷 (5장, 각 해상도) 및 홍보용 그래픽 제작",
        "스토어 설명문 (한국어) 작성",
        "개인정보 처리방침 웹페이지 호스팅 (필수)",
        "이용약관 페이지 호스팅",
        "Google Play Console 개발자 계정 ($25 일회성) 등록",
        "App Store Connect 계정 (연 $99) 등록",
        "연령 등급 심사 (콘텐츠 분류)",
    ]),
]

for step_title, tasks in next_steps:
    content += h3(step_title)
    for task in tasks:
        content.append(bullet(f"[  ] {task}"))
    content.append(spacer(3))

content.append(spacer())
content += h2("5.4 현재 앱 실행 방법 (데모 모드)")
for t_ in [
    "flutter run -d <device> 로 실행",
    "로그인 화면에서 '데모로 시작' 버튼 → 데모은열 계정으로 진입",
    "Firebase 미연동 상태에서도 모든 핵심 기능 체험 가능",
    "실제 크레딧은 로컬 메모리에만 저장 (앱 재시작 시 초기화)",
    "Firebase 연동 후에는 전화번호 인증 로그인으로 전환",
]:
    content.append(bullet(t_))

content.append(spacer(10))
content.append(HRFlowable(width="100%", thickness=1, color=PRIMARY, spaceAfter=10))
content.append(Paragraph(
    "Focus Cash — 집중하면 돈이 되는 시간",
    s("Footer", fontSize=10, textColor=TEXT_GRAY, alignment=TA_CENTER)
))

# ─── Build PDF ─────────────────────────────────────────────────────────────────
OUTPUT = "FocusCash_종합계획서.pdf"
doc = SimpleDocTemplate(
    OUTPUT,
    pagesize=A4,
    rightMargin=20*mm,
    leftMargin=20*mm,
    topMargin=20*mm,
    bottomMargin=20*mm,
    title="Focus Cash 종합 계획서",
    author="Focus Cash Team",
)

doc.build(content)
print(f"\nPDF saved: {OUTPUT}")
