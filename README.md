#### 데이터 목록

`-` 제공 데이터  
- Data1.csv : 지하철 혼잡도 정보 (호선, 역번호, 역명, 시간대별 혼잡도)
- Data3.csv : 자치구별 지하철 역 정보 (호선, 자치구)

`-` 공공데이터 
- 서울교통공사_역사건축정보_2020.csv : (역명, 연식 등)
- 서울교통공사_역사심도정보_2020.csv : (역명, 심도 등)
- 서울교통공사_월별승하차인원_2020.csv : (역명, 월별 승하차 인원 등)
- 서울교통공사_환기구정보_2020.csv : (역명, 환기구 정보)

`-` 가공데이터 
- 서울교통공사_역정보 -> 지하철 역 위도 경도 좌표 
- 서울교통공사 공기질 2020 -> 5가지 공기질 요소 데이터

#### 데이터 전처리 

**데이터 프레임 생성**
1. 각 csv 파일을 데이터프레임으로 만든 뒤 필요없는 열을 제거, 결측치 대체 및 삭제합니다. 
2. 혼잡도와 승객수는 역별 평균값을 취하여 사용한다. 
3. 모든 데이터 프레임의 기본키를 ['호선','역명'] 형식으로 맞춘다. 
4. 기본키를 이용하여 최종 병합한다. 

<최종 병합된 DataFrame>  
![image](https://user-images.githubusercontent.com/67791317/203371656-86f3693f-ae43-4bd0-8400-f6680b25295c.jpeg)

**공기질 데이터 변수 재조합**
1. 종합 공기질 점수를 계산하기 위해 5가지 척도를 종합하여 생성한다. 
```python
공기질척도 = (미세먼지 / 100) + (포름알데히드 / 100 )+ (초미세먼지 / 50) + (일산화탄소 / 10) + (이산화탄소 / 1000)
```
![image](https://user-images.githubusercontent.com/67791317/203372780-a557cde6-db0d-473a-8508-3a776b46d2da.jpeg)

2. 각 변수들의 영향력을 동일하게 하기 위해, feature scaling 진행 
3. Standard Scaler로 정규화 진행, MinMax Scaler를 통해 피쳐의 범위를 0~1 사이로 변환

#### 데이터 탐색 

**상관관계 탐색**

상관계수행렬을 만들어 공기질 점수와 상관관계를 파악하고 히트맵을 통해 시각화해 확인. 

<img width="456" alt="image" src="https://user-images.githubusercontent.com/67791317/203373835-0b5fc407-fabf-43dd-b617-4b7054d97052.png">

**지도 시각화**

folium 패키지를 활용하여 지하철역별 공기질과 승객수를 지도시각화하여 표현
원은 지하철 역을 나타내며, 원의 색이 빨갈 수록 공기질이 나쁘고 크기가 클 수록 승객수가 많다. 

<img width="632" alt="image" src="https://user-images.githubusercontent.com/67791317/203374381-a69ad6dc-bdcd-46ca-96d0-06ae695a9fa6.png">

#### 분석 모델 

K-mean 클러스터링을 통해 공기정화시스템 설치후보구역을 선정  

1. 클러스터링을 통해 변수 3개 (공기질점수, 평균혼잡도, 환승역개수)를 사용함. 
2. 해당 변수 우선수위는 공기질 점수 > 평균혼잡도 > 환승역개수로 설정함.   
3. K = 1 ~ 10 까지 놓고, 각 k-means clustering으로 얻은 모델의 군집내 총 제곱합을 plot함. 

<img width="441" alt="image" src="https://user-images.githubusercontent.com/67791317/203375193-fe9675de-f60e-4094-9639-8b2dc978fb8c.png">

4. plot이 감소하는 추세가 급격한 지점이 elbow point로 해당 지점을 군집의 개수로 사용. 
5. 각 군집별 변수 평균을 계산함. 

![image](https://user-images.githubusercontent.com/67791317/203375788-c024ef10-719a-4001-ac39-5bb3b601c4c3.jpeg){: width="70%" height="50%"}

6. 0번 군집이 공기질 점수와 평균혼잡도와 환승역 개수가 크므로 0번 군집에 해당하는 역을 우선 설치군집으로 채택

#### 클러스터링 결과 시각화

<img width="562" alt="image" src="https://user-images.githubusercontent.com/67791317/203375817-f245e61a-c0dc-41cf-8a19-1e90abe8d918.png">

#### 회귀분석 (군집 내 우선순위)

공기질 척도를 사용하여 각 변수의 가중치를 생성 

```python
후보선정지수 = 0.1676 * 총승객수 + 0.1971 * 레일면고 + 0.1956 * 정거장깊이 + 0.1196 * 환기구 + 0.2820 * 연식
```
![image](https://user-images.githubusercontent.com/67791317/203375874-acdc0a79-fadc-459d-bb9f-17218f2b8523.jpeg)

#### 최종 결과 

회귀분석을 통해 가중치를 생산한 값을 적용하여 후보선정지수를 계산  
가장 지수가 높은 역 3개를 뽑아 최종 입지로 선정하였다. 

**1호선 서울역, 2호선 강남역, 2호선 시청역**
![image](https://user-images.githubusercontent.com/67791317/203375901-5667c97b-1fa2-431c-906f-783dd032c606.jpeg)

### 레퍼런스 

#### 연구 배경 

- Web) 서울 교통공사 Webzine, 2022.01, http://webzine.seoulmetro.co.kr/enewspaper/articleview.php?master=&aid=1902&sid=73&mvid=692
- 기사) 심우섭, [리포트+] "안에서도 목이 칼칼" 실내 미세먼지 어쩌나 , SBS, 1, https://news.sbs.co.kr/news/endPage.do?news_id=N1005168647
- Web) 인천교통공사 ,https://www.ictr.or.kr/main/safety/environment/sense.jsp
- 논문) 한국환경사회정책연구소, ‘지하철역내 공기질에 대한 문제점과 개선방안 :3,’, 2003, Vol.2003.No.4, 539, 39~48

#### 데이터 참고 

- Web) 서울교통공사 공공데이터 제공, http://www.seoulmetro.co.kr/kr/board.do?menuIdx=551

#### 코드 

- Stack overflow
- Web) 데 박, https://blog.naver.com/111ambition/222503252689
- Web) 테디코드, https://teddylee777.github.io/visualization/folium