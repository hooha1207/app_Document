문서 편집 모바일 앱 구현 문서

해당 앱은 다른 앱에서도 쓸 수 있게 만들 예정이다.
사용 시나리오는 다른 앱에서 텍스트 및 미디어를 작성할 때 사용된다


절대 webview를 쓰면 안된다
native로 구현해야 된다


"F:\DIYworkbook\dev_app001\diy_workbook"
현재 위 프로젝트에서 사용된 rich text editor를 기반으로 만들 예정이다
위 프로젝트의 rich text eidtor를 분석해서 보고해


최종 목표는 rich text editor에 특화된 앱을 만들고
이를 diy workbook의 text 및 미디어를 추가하는 부분에 이식할 예정이다


미디어 추가를 다른 방식으로 해석하고자 한다.
여기서 말하는 미디어는 이미지, 음원, 영상, 유튜브를 모두 뜻한다
미디어 블록이 한 줄을 전부 차지하는 게 아니라,
미디어 블록이 차지하는 영역을 뺸 영역을 텍스트 영역으로 인지하는 것이다.
글은 왼쪽부터 읽기 때문에 왼쪽 영역이 우선권을 가지고 있다.



구현할 기능
[
bold
under line

font
text size

text color
text background color

정렬

줄 및 단락 간격

들여쓰기
내어쓰기

서식 초기화

이미지, 음원, 영상, 유튜브 추가

링크 하이퍼링크
링크 대체 텍스트
]
