####패키지####
library(RSQLite)
library(DBI)
library(dplyr)
library(ggplot2)
library(lawstat)
################

setwd("C:/Users/kw102/Desktop/2021-1학기 비대면수업/통계데이터베이스/기말고사")

station <- read.csv("역주소현황.csv", header = T)
air <- read.csv("공기질.csv", header = T)
count <- read.csv("승하차인원.csv", header = T)

View(station)
View(air)
View(count)

###########################* 데이터 전처리 *#################################

#****************air 데이터********************#

#열이름 변경
colnames(air) <- c("호선", "역명", "미세먼지", "이산화탄소", "포름알데히드", "일산화탄소") 

#역명에 띄어쓰기가 들어간 값들 띄어쓰기 제거
air$역명 <- gsub("\\s", "", air$역명)





#****************count 데이터******************#

#count 열이름 변경
colnames(count) <- c("호선", "역번호", "역명", "1월", "2월", "3월",
                     "4월","5월","6월","7월","8월","9월","10월","11월","12월")

#count데이터의 역 이름에 호선이 붙어있으면 제거  ex)강남(2)
temp <- count$역명[grep("\\(.\\)$", count$역명)] 
count$역명[grep('\\(..$', count$역명)] <- substr(temp, 0, nchar(temp)-3)





#***********************Station 데이터*******************#


#station 열이름 변경
colnames(station) <- c("번호", "역명", "행정동(법정동)", "역주소", "우편번호")


##station데이터에 호선 속성을 추가하고, 기존 역명에 호선을 제거
station$호선 <- substr(station$역명, nchar(station$역명)-2, nchar(station$역명)-2)

for (i in 1:length(station$호선)){
  station$호선[i] = paste(c(station$호선[i], "호선"), collapse = "")
  
}
station$역명 <- substr(station$역명, 0, nchar(station$역명)-4)


##station에 없는 역이 count와 air에 존재
##join을 통해 station의 값들을 update
station_merge <- left_join(count, station, by = c("역명", "호선")) #station과 count outer-join

station_merge <- full_join(station_merge, air, by = c("역명", "호선")) #station_merge와 air outer_join

station_merge <- station_merge[, c("호선", "역명", "역번호", "행정동(법정동)", "역주소", "우편번호")] #필요한 열만 추출

station_merge[is.na(station_merge$역번호), ] #역번호가 NA인 값들 확인

station_merge[is.na(station_merge$역번호), "역번호"] <- c(343, 435, 2649) #값 대체

station <- station_merge


#행정동과 법정동을 분리 
station$행정동 <- NA; station$법정동 <- NA

for(i in 1:nrow(station)){
  station$행정동[i] <- strsplit(station$`행정동(법정동)`[i], "\\(")[[1]][1]
  station$법정동[i] <- strsplit(station$`행정동(법정동)`[i], "\\(")[[1]][2]
  station$법정동[i] <- substr(station$법정동[i], 1, nchar(station$법정동[i]) - 1 )
}




#air 데이터에 역번호 열 생성(left join)
air <- left_join(air, station_merge, by = c("역명", "호선"))


##count의 월별 데이터를 월 속성과 데이터 속성으로 나눔
#빈 5개의 열을 가진 데이터프레임 생성
new_count <- data.frame(0, 0, 0, 0, 0)
colnames(new_count) <- c("호선", "역번호", "역명", "월", "승하차인원")


for( i in 0 : (nrow(count)-1) ){
  for(j in 1:12){
    new_count[(i * 12) + j, "월"] <- j #월 속성
    new_count[(i * 12) + j, c(1,2,3,5)] <- count[i + 1, c(1:3, j + 3), ] #호선, 역버호, 역명, 승하차인원을 count에서 가져옴
  }
}
count <- new_count


#데이터에서 테이블의 속성들만 잘라냄
air <- air[, c(7, 3:6)]
count <- count[ ,c(2, 4, 5)]
station <- station[, c(3, 1, 2, 7, 8, 5, 6)]

#역번호로 정렬
air <- arrange(air, by = 역번호)
count <- arrange(count, by = 역번호)
station <- arrange(station, by = 역번호)


#DB로 만들기 위해 열이름을 변경
colnames(station) <- c("StationID", "Line", "Name", "HDong", "BDong", "Address", "ZipCode")
colnames(count) <- c("StationID", "Month", "PCount")
colnames(air) <- c("StationID", "FineDust", "CarbonDioxide", "Formaldehyde", "CarbonMonoxide")


#Python 작업을 위해 파일을 새로 저장
write.csv(air, "AirQuality.csv", row.names = F, fileEncoding = "UTF-8")
write.csv(count, "Passengers.csv", row.names = F, fileEncoding = "UTF-8")
write.csv(station, "Station.csv", row.names = F, fileEncoding = "UTF-8")

###################################################################################



############################DB 생성###############################################

#StationData DB 생성
conn <- dbConnect(SQLite(), dbname = './StationData.sqlite')

#foreign_keys 옵션 설정
dbExecute(conn, "PRAGMA foreign_keys = ON")

#################################
######1. Station 테이블 생성#####
sql <- "CREATE TABLE IF NOT EXISTS Station
        (StationID TEXT,
        Line TEXT not null,
        Name TEXT not null,
        HDOng TEXT,
        BDong TEXT,
        Address TEXT,
        ZipCode TEXT,
        PRIMARY KEY(StationID) )"

rs <- dbSendQuery(conn, sql)
dbClearResult(rs)

#정상적으로 만들어졌는지 확인
dbExistsTable(conn, "Station")

#기존 Station 데이터프레임을 overwrite하여 새로 테이블 생성
dbWriteTable(conn = conn, name = "Station", station, overwrite = TRUE, row.names = FALSE)

#데이터 확인
dbReadTable(conn, "Station")

#테이블 가져오기
sql <- "SELECT * FROM Station"
Station <- dbGetQuery(conn, sql) 

##############################

###2. Passengers 테이블 생성###
sql <- "CREATE TABLE IF NOT EXISTS Passengers
        (StationID TEXT,
        Month INTAGER,
        PCount INTAGER not null,
        PRIMARY KEY (StationID, Month),
        FOREIGN KEY (StationID) REFERENCES Station )"

rs <- dbSendQuery(conn, sql)
dbClearResult(rs)        

#정상적으로 만들어졌는지 확인
dbExistsTable(conn, "Passengers")

#기존 Passengers 데이터프레임을 overwrite하여 새로 테이블 생성
dbWriteTable(conn = conn, name = "Passengers", count, overwrite = TRUE, row.names = FALSE)

#데이터 확인
dbReadTable(conn, "Passengers")

#테이블 가져오기
sql <- "SELECT * FROM Passengers"
Passengers <- dbGetQuery(conn, sql) 

#############################


####3. AirQuality 테이블 생성###
sql <- "CREATE TABLE IF NOT EXISTS AirQuality
        (StationID TEXT,
        FineDust REAL not null,
        CarbonDioxide INTAGER not null,
        Formaldehyde REAL not null,
        CarbonMonoxide REAL not null,
        PRIMARY KEY (StationID),
        FOREIGN KEY (StationID) REFERENCES Station )"

rs <- dbSendQuery(conn, sql)
dbClearResult(rs)

#정상적으로 만들어졌는지 확인
dbExistsTable(conn, "AirQuality")

#기존 AirQuality 데이터프레임을 overwrite하여 새로 테이블 생성
dbWriteTable(conn = conn, name = "AirQuality", air, overwrite = TRUE, row.names = FALSE)

#데이터 확인
dbReadTable(conn, "Airquality")

#테이블 가져오기
sql <- "SELECT * FROM AirQuality"
AirQuality <- dbGetQuery(conn, sql) 
##############################
#################################################################################



#####################################데이터 요약################################


###Station 데이터 요약###

#호선별 역의 개수(서울권)
sql <- "SELECT Line, COUNT(*) StationNum
        FROM Station
        GROUP BY Line"

dbGetQuery(conn, sql)



#가장 지하철이 많이 다니는 지역 
gu <- c()
for(i in 1:nrow(Station)){
  gu[i] <- strsplit(Station$Address[i], " ")[[1]][2]
}


# 송파구가 가장 지하철이 많이 다닌다
table(gu)[max(table(gu)) == table(gu)] 


#가장 지하철이 많이 다니는 동은 신당동이다
table(Station$BDong)[table(Station$BDong) == max(table(Station$BDong))] 

#########################


###Passengers 데이터 요약####

summary(Passengers$PCount)  # 승객 수의 요약통계량
boxplot(Passengers$PCount)  # 승객 수의 상자그림


#평균 승객 수 => 1034625
sql <- "SELECT AVG(P.PCount) AVGPassengers
        FROM Station S
        JOIN Passengers P
        ON S.StationID = P.StationID"

dbGetQuery(conn, sql)


#평균 승객 수보다 승객이 많은 호선
sql <- "SELECT S.LINE, AVG(P.PCount) AVGPassengers
        FROM Station S
        JOIN Passengers P
        ON S.StationID = P.StationID
        GROUP BY S.Line
        HAVING AVGPassengers >= 1034625"

dbGetQuery(conn, sql) # 1, 2, 3, 4호선은 승객이 많이 탄다.

###########################


###AirQuality 데이터 요약###

summary(AirQuality) #AirQuality 데이터 요약통계량


#AirQuality 속성별 상자그림
par(mfrow = c(1,4))
FineDust <- boxplot(AirQuality$FineDust, main = "FineDust") #AirQuality 상자그림
CO2 <- boxplot(AirQuality$CarbonDioxide, main = "CO2") #AirQuality 상자그림
Form <- boxplot(AirQuality$Formaldehyde, main = "Formaldehyde") #AirQuality 상자그림
CO <- boxplot(AirQuality$CarbonMonoxide, main = "CO") #AirQuality 상자그림

par(mfrow = c(1,1))

##미세먼지 농도가 평균이상인 호선 구하기
mean(AirQuality$FineDust) #평균 미세먼지 농도

#호선별 미세먼지의 평균을 구하고, HAVING절을 이용해 평균 미세먼지보다 높은 호선만 추출
sql <- "SELECT S.Line, AVG(A.FineDust) AVGDust
        FROM Station S
        JOIN AirQuality A
        ON S.StationID = A.StationID
        GROUP BY S.Line
        HAVING AVGDust > 66.04"

dbGetQuery(conn, sql)


##이산화탄소 농도가 평균이상인 호선 구하기
mean(AirQuality$CarbonDioxide) #평균 이산화탄소 농도

#호선별 CO2의 평균을 구하고, HAVING절을 이용해 평균 CO2보다 높은 호선만 추출
sql <- "SELECT S.Line, AVG(A.CarbonDioxide) AVGCO2
        FROM Station S
        JOIN AirQuality A
        ON S.StationID = A.StationID
        GROUP BY S.Line
        HAVING AVGCO2 > 550"

dbGetQuery(conn, sql)


##포름알데히드 농도가 평균이상인 호선 구하기
mean(AirQuality$Formaldehyde) #평균 포름알데히드 농도

#호선별 CO2의 평균을 구하고, HAVING절을 이용해 평균 CO2보다 높은 호선만 추출
sql <- "SELECT S.Line, AVG(A.Formaldehyde) AVGForm
        FROM Station S
        JOIN AirQuality A
        ON S.StationID = A.StationID
        GROUP BY S.Line
        HAVING AVGForm > 7.1"

dbGetQuery(conn, sql)


##일산화탄소 농도가 평균이상인 호선 구하기
mean(AirQuality$CarbonMonoxide) #평균 일산화탄소 농도

#호선별 CO의 평균을 구하고, HAVING절을 이용해 평균 일산화탄소보다 높은 호선만 추출
sql <- "SELECT S.Line, AVG(A.CarbonMonoxide) AVGCO
        FROM Station S
        JOIN AirQuality A
        ON S.StationID = A.StationID
        GROUP BY S.Line
        HAVING AVGCO > 0.7275"

dbGetQuery(conn, sql)


############################


##############################################################################



###############################데이터 분석###################################


#####월별 / 호선별 / 방학기간별 승객수의 차이 분석#####


##1) 호선별 승객수 분석

#DB에서 역별 월평균 승객수 추출
sql <- "SELECT S.StationID, S.Name, S.Line, AVG(P.PCount) AVGPassengers
        FROM Station S
        JOIN Passengers P
        ON S.StationID = P.StationID
        GROUP BY P.StationID"
AVGP <- dbGetQuery(conn, sql)

#호선별 boxplot 확인
boxplot(AVGPassengers ~ Line, data = AVGP) #호선별 승객수가 차이가 있어보인다

#호선별 승객수의 평균이 차이가 있는지 검정(ANOVA)
summary(aov(AVGPassengers ~ Line, data = AVGP))
                  #*유의수준 0.05에서 p-value < 0.05이므로, 영가설 H0 : 호선별 평균 승객수는 같다를 기각한다.
                 #*호선별 승객수는 같다고 할 수 없다.

#호선별 평균 승객수
AVGP %>% group_by(Line) %>% summarise(mean = mean(AVGPassengers))

##2) 월별 승객수 분석

#월별 승객수 boxplot 확인
boxplot(PCount ~ Month, data = Passengers) #월에 따라 큰 차이는 없어보인다


#월별 평균 승객수
Passengers %>% group_by(Month) %>% summarise(mean = mean(PCount))

#월별 승객수의 평균의 차이가 있는지 검정(ANOVA)
summary(aov(PCount ~ Month, data = Passengers) )
                #* p-value > 0.05이므로, 영가설을 기각하지 못한다.
                #* 따라서 월별 승객수는 같다고 할 수 있다.


#방학 기간과 비방학 기간(1,2, 8,9월 -> 방학)별 평균의 차이가 있는지 검정(t test)

#방학일 경우 vaction은 1, 아니면 0
Passengers$vacation <- ifelse(Passengers$Month %in% c(1, 2, 8, 9), 1, 0)

#방학/ 비방학별 승객의 평균
Passengers %>% group_by(vacation) %>% summarise(mean = mean(PCount)) #방학일때 비방학일때보다 10% 승객이 감소하였다

#t검정 실행
t.test(PCount ~ vacation, data = Passengers) 
                      #* P-vaule < 0.05로 H0 : 두 모평균이 같다 를 기각한다
                      #* 즉 방학일 때와 비방학일 때 승객의 수가 유의한 차이가 있다고 할 수 있다.




###호선별 / 구별 대기상태 분석####


##1) 호선별 대기상태 확인

#역 정보와 대기상태 JOIN
sql <- "SELECT S.Name, S.Line, A.FineDust, A.CarbonDioxide, A.Formaldehyde, A.CarbonMonoxide
        FROM Station S
        JOIN AirQuality A
        ON S.StationID = A.StationID"

Air <- dbGetQuery(conn, sql)


#호선별 대기상태 boxplot (CO2와 CO가 호선에 따라 다르게 보인다)
boxplot(Air$FineDust ~ Air$Line, col = rainbow(8))
boxplot(Air$CarbonDioxide ~ Air$Line, col = rainbow(8))
boxplot(Air$Formaldehyde ~ Air$Line, col = rainbow(8))
boxplot(Air$CarbonMonoxide ~ Air$Line, col = rainbow(8))

#호선별 각 대기품질 지표 anova
summary(aov(Air$FineDust ~ Air$Line))
summary(aov(Air$CarbonDioxide ~ Air$Line))
summary(aov(Air$Formaldehyde ~ Air$Line))
summary(aov(Air$CarbonMonoxide ~ Air$Line))
#* boxplot에서 보이는 것처럼 Co2와 CO의 p-value < 0.05로 호선별 평균이 같다고 할 수 없다.
#* 따라서 호선별로 CO2와 CO농도의 차이가 있다.



#이산화탄소 농도와 일산화탄소 농도의 관계
CarbonPlot <- ggplot(data = Air, aes(x = CarbonDioxide, y = CarbonMonoxide)) + 
  geom_jitter(aes(color = as.factor(Line)), size = 2)  # 일산화탄소가 겹쳐있기 때문에 , jitter로 산점도를 그림
CarbonPlot + stat_smooth(method = "lm") #추세선을 그림
#둘의 상관관계가 보이지 않는다.


cor(Air$CarbonDioxide, Air$CarbonMonoxide) #*둘의 상관계수는 0.03으로  선형적인 상관성이 존재하지 않는다
                                          #* 일산화탄소 농도와 이산화탄소 농도는 당연히 양의 상관관계가 존재할 줄 알았으나,
                                          #* 의외의 결과를 얻었다.

#미세먼지, 이산화탄소, 포름알데히드, 일산화탄소간의 상관계수
cor(Air[,3:6]) #상관계수가 0.2이하인것으로 보아 서로 상관관계가 없다고 할 수 있다.

####################################################################################

