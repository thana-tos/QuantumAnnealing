      PROGRAM ISING2
      IMPLICIT NONE
      INTEGER N, N_STEP
      REAL*8 KT_INIT, KT_FIN, ALPHA, SETALPHA, KT
      INTEGER I, T, X, Y
      INTEGER TMP
!     SPIN_A(:): 繊維前の状態,  SPIN_B(:): 遷移したとしたときの状態
      REAL*8, ALLOCATABLE, DIMENSION(:,:) :: SPIN_A, SPIN_B
!     ENERG_A : 繊維前のエネルギー, ENERG_B : 遷移したとしたときのエネルギー, M: 磁化
      REAL*8 ENERG, ENERG_A, ENERG_B, MAGNETIZATION, M
!     J : カップリング
      REAL*8, ALLOCATABLE, DIMENSION(:,:,:,:) :: J
!     BETA : 1/KT, P: 反転させる確率, P_BASE : P>P_BASEであるときに反転させる
      REAL*8 BETA, P, P_BASE
!     SITE_X, SITE_Y : 反転させるサイトのX座標, Y座標
      INTEGER SITE_X, SITE_Y
!     EXPECTED_E, EXPECTED_M : DATA_DEVIDE ごとの期待値
      REAL*8 EXPECTED_E, EXPECTED_M
!     RESULT_E, RESULT_M : DATA_DEVIDE ごとの結果を格納
      REAL*8, ALLOCATABLE::RESULT_E(:), RESULT_M(:)
!     RESULT_EXPECTED : 熱平衡に達したあとの, DATA_DEVIDE ごとの期待値を格納
      REAL*8, ALLOCATABLE::RESULT_EXPECTED_E(:),RESULT_EXPECTED_M(:)
!     EPSILON : 微小な値
      REAL * 8,PARAMETER::EPSILON = 1E-5
!     OUT : 書き出しファイルのための装置番号
      INTEGER,PARAMETER::OUT = 17
!     IN : 読み込みファイルのための装置番号
      INTEGER,PARAMETER::IN = 18

      INTEGER DATA_MAX
!    SET DATA_DEVIDE!
!     DATA_DEVIDE : DATA IS RECORDED EVERY @DATA_MAX TRIAL AND EXPECTED VALUE IS CALUCULATED USING @DATA_MAX RESULTS
      INTEGER, PARAMETER::DATA_DEVIDE = 3000
!    SET EQUILIBRIUM_VALUE!
!     EQUILIBRIUM_VALUE : REGARD A STATE AS EQUILIBRIUMU STATE IF TIME IS BIGGER THAN THE VALUE OF THE PARAMETER
!     IT IS SET BY RATE(0 ~ 10)
      INTEGER*8::EQUILIBRIUM_POINT = 3

!     ======== INITIALIZE ========
!     OPEN FILE
      OPEN(OUT,FILE = 'SpinGlass_SA.dat', STATUS = 'UNKNOWN')
      OPEN(IN, FILE = "SG.dat", STATUS = 'UNKNOWN')

!     SET RANDOM SEED
      CALL RND_SEED

!     READ N, KT, KT_FIN FROM COMMANDLINE
      PRINT * , 'N_STEP'
      READ(*, *) N_STEP
      PRINT * , 'KT_INIT'
      READ(*, *) KT_INIT
!      PRINT * , 'KT_FIN'
!      READ(*, *) KT_FIN

      DATA_MAX = N_STEP / DATA_DEVIDE
      EQUILIBRIUM_POINT = INT(DATA_MAX * (EQUILIBRIUM_POINT / 10.0))

      READ(IN,*) N
      ALLOCATE(J(N,N,N,N))
      ALLOCATE(SPIN_A(N,N))
      ALLOCATE(SPIN_B(N,N))
      ALLOCATE(RESULT_E(DATA_DEVIDE))
      ALLOCATE(RESULT_M(DATA_DEVIDE))
      ALLOCATE(RESULT_EXPECTED_E(DATA_MAX - EQUILIBRIUM_POINT))
      ALLOCATE(RESULT_EXPECTED_M(DATA_MAX - EQUILIBRIUM_POINT))

!     INITIALIZE OUTPUT FILE
      CALL SPNDAT(-1,SPIN_A,N,ENERG_A)

!     INITIALIZE SPIN & ENERG_B
      CALL INIT_ISING(SPIN_A,N)
      DO Y = 1, N
        DO X = 1, N
          SPIN_B(Y,X) = SPIN_A(Y,X)
        ENDDO
      ENDDO

      CALL INIT_COUPLING(J,N,IN)

      ENERG_A = ENERG(J, SPIN_A, N)
!      PRINT * , ENERG_A

      KT = KT_INIT
      KT_FIN = EPSILON
      ALPHA = SETALPHA(KT_INIT,KT_FIN,N_STEP)
      PRINT * , "ALPHA", ALPHA

!     ======== MONTE-CARLO SIMULATION ========
!     DO WHILE KT > EPS
!     N_STEP = 100
      DO T = 1, N_STEP
        IF(KT == 0) THEN
          BETA = 1E5
        ELSE
         BETA = 1/DBLE(KT)
        ENDIF

!      SELECT UPDATED SITE
        CALL CHOOSE(SITE_X, SITE_Y, N)
!       PRINT * ,'SITE_X : ', SITE_X,' SITE_Y', SITE_Y
!       UPDATE SPIN BASED ON SPIN_A
        CALL REVERSE_SPIN(SITE_X, SITE_Y, SPIN_A, SPIN_B, N)

!       CALCULATE ENERG_B
        ENERG_B = ENERG(J, SPIN_B, N)

!       CALCULATE P
!       PRINT * , 'T',T, 'ENERG_B', ENERG_B , 'ENERG_A', ENERG_A
        IF (ENERG_B - ENERG_A <= 0) THEN
          P = 1
        ELSE
          P = EXP(-BETA * (ENERG_B - ENERG_A))
        ENDIF

!       UPDATE ISING BASED ON PROBABILITY P
        CALL RANDOM_NUMBER(P_BASE)

        IF (P >= P_BASE) THEN
!         PRINT * , 'UPDATE'
          CALL UPDATE_ISING(SPIN_A, SPIN_B, N)
          ENERG_A = ENERG_B
        ENDIF

!       CALCULATE MAGNETIZATION
        M = MAGNETIZATION(SPIN_A, N)

!       CONTAIN VALUE OF ENERG AND M^2 IN ARRAY
        RESULT_E(MOD(T,DATA_DEVIDE) + 1) = ENERG_A
        RESULT_M(MOD(T,DATA_DEVIDE) + 1) = M**2

!       OUTPUT EXPECTED VALUE EVERY 1000 SAMPLE TO FILE
        IF (MOD(T,DATA_DEVIDE) == 0) THEN
          EXPECTED_E = SUM(RESULT_E) / SIZE(RESULT_E)
          EXPECTED_M = SUM(RESULT_M) / SIZE(RESULT_M)
          PRINT * , KT, T, EXPECTED_E
          PRINT * , KT, T, EXPECTED_M
          TMP = INT(T/DATA_DEVIDE) - EQUILIBRIUM_POINT
!         OUTPUT FOR ANIMATION
          CALL SPNDAT(INT(T/DATA_DEVIDE),SPIN_A,N,EXPECTED_E)
!         CONTAIN EXPECTED OF ENERG AND M^2 IN ARRAY
          IF(TMP > 0) THEN
            RESULT_EXPECTED_E(I) = EXPECTED_E
            RESULT_EXPECTED_M(I) = EXPECTED_M
!           PRINT * , T, EXPECTED_E
!           PRINT * , T, EXPECTED_M
          ENDIF

!       IF YOU WANT TO OUTPUT ENERGY OR MAGNETIZATION EVERY @DATA_DEVIDE TRIAL, COMMENT IN ONE OF THE NEXT SEQUENCE
!       WRITE(OUT, *) T, ENERG_A
!       WRITE(OUT, *) T, M**2
        ENDIF

!       UPDATE TEMPARATURE
        KT = ALPHA**T * KT_INIT

      ENDDO

!     PRINT SPIN
      DO Y = 1, N
        DO X = 1, N
!         PRINT *, SPIN_A(X,Y)
        ENDDO
!       PRINT * , ''
      ENDDO

      DO I = 1, DATA_MAX - EQUILIBRIUM_POINT
!       PRINT *, RESULT_EXPECTED_E(I), RESULT_EXPECTED_M(I)
      ENDDO

!     IF YOU WANT TO OUTOUT EXPECTED_VALUE, COMMENT IN SEQUENCE INCLUDING WRITE
      EXPECTED_E = SUM(RESULT_EXPECTED_E) / SIZE(RESULT_EXPECTED_E)
      EXPECTED_M = SUM(RESULT_EXPECTED_M) / SIZE(RESULT_EXPECTED_M)
!     WRITE(OUT, *) EXPECTED_E, EXPECTED_M

      DEALLOCATE(J)
      DEALLOCATE(SPIN_A, SPIN_B)
      DEALLOCATE(RESULT_E)
      DEALLOCATE(RESULT_M)
      DEALLOCATE(RESULT_EXPECTED_E)
      DEALLOCATE(RESULT_EXPECTED_M)
      CLOSE(OUT)
      END


!     CALCULATE ENERGY OF GENERAL SITE
      DOUBLE PRECISION FUNCTION ENERG(J, SPIN, N)
      IMPLICIT NONE
      REAL*8 J(N,N,N,N)
      REAL*8 J_VAL
      REAL*8,DIMENSION(N,N)::SPIN
      INTEGER N, IX, IY, JX, JY

      ENERG = 0.0D0

      DO IX = 1, N
        DO IY = 1, N
          DO JX = 1, N
            DO JY = 1, N
              J_VAL = J(IX, IY, JX, JY)
              ENERG = ENERG - J_VAL * SPIN(IY, IX) * SPIN(JY, JX)
            ENDDO
          ENDDO
        ENDDO
      ENDDO

      END

      DOUBLE PRECISION FUNCTION MAGNETIZATION(SPIN, N)
      IMPLICIT NONE
      INTEGER N
      REAL*8,DIMENSION(N,N)::SPIN
      MAGNETIZATION = SUM(SPIN) / SIZE(SPIN)
      END

!     SET RANDOM SEED
      SUBROUTINE RND_SEED
      IMPLICIT NONE
      INTEGER I , SEEDIZE
      INTEGER,ALLOCATABLE :: SEED(:)

      CALL RANDOM_SEED(SIZE=SEEDIZE)
      ALLOCATE(SEED(SEEDIZE))
      CALL RANDOM_SEED(GET = SEED)
      DO I = 1, SEEDIZE
        CALL SYSTEM_CLOCK(COUNT = SEED(I))
      ENDDO

      CALL RANDOM_SEED(PUT = SEED(:))
      DEALLOCATE(SEED)
      END

!     INTIALIZE SPIN
      SUBROUTINE INIT_ISING(SPIN, N)
      IMPLICIT NONE
      INTEGER I, J, N
      REAL*8,DIMENSION(N,N)::SPIN
      REAL*8,PARAMETER::EPSILON = 1E-5

      DO J = 1, N
        DO I= 1,N
          CALL RANDOM_NUMBER(SPIN(I,J))
          SPIN(I,J) = NINT(SPIN(I,J))
          IF (ABS(SPIN(I,J)) < EPSILON) THEN
            SPIN(I,J) = -1.0
          ENDIF
        ENDDO
      ENDDO
      END

      SUBROUTINE INIT_COUPLING(J,N,IN)
      IMPLICIT NONE
      REAL*8 J(N,N,N,N)
      INTEGER N, IX, IY, JX, JY
      REAL*8 TMPJ
      INTEGER IN
      INTEGER COUNT


      DO IX = 1, N
        DO IY = 1, N
          DO JX = 1, N
            DO JY = 1, N
              J(IX,IY,JX,JY) = 0
            ENDDO
          ENDDO
        ENDDO
      ENDDO


      DO
        READ(IN,*,END=100) IX, IY, JX, JY, TMPJ
        J(IX,IY,JX,JY) = TMPJ
!       PRINT *, J(IX,IY,JX,JY)
        COUNT = COUNT + 1
      ENDDO
  100 CLOSE(IN)
      PRINT * ,COUNT

      END

!     CHOOSE UPDATED SITE
      SUBROUTINE CHOOSE(SITE_X, SITE_Y, N)
      IMPLICIT NONE
      INTEGER SITE_X, SITE_Y, N
      REAL*8 TMP

      CALL RANDOM_NUMBER(TMP)
      SITE_X = CEILING(TMP * N)
      CALL RANDOM_NUMBER(TMP)
      SITE_Y = CEILING(TMP * N)

      END

!     UPDATE ISING BASED ON A
      SUBROUTINE REVERSE_SPIN(SITE_X, SITE_Y, SPIN_A, SPIN_B, N)
      IMPLICIT NONE
      INTEGER N, X,Y
      INTEGER SITE_X, SITE_Y
      REAL*8,DIMENSION(N,N)::SPIN_A, SPIN_B
      REAL*8,PARAMETER::EPSILON = 1E-5
      DO Y = 1, N
        DO X = 1, N
          IF(X == SITE_X .AND. Y == SITE_Y) THEN
            IF(ABS(SPIN_A(Y,X) - 1.0) < EPSILON) THEN
              SPIN_B(Y,X) = -1.0
            ELSE
              SPIN_B(Y,X) = 1.0
            ENDIF
          ELSE
            SPIN_B(Y,X) = SPIN_A(Y,X)
          ENDIF
        ENDDO
      ENDDO
      END

!     REVERSE SPIN OF MOLECULAR ON THE CHOSEN SITE
      SUBROUTINE UPDATE_ISING(SPIN_A, SPIN_B, N)
      IMPLICIT NONE
      INTEGER N,X,Y
      REAL*8,DIMENSION(N,N)::SPIN_A, SPIN_B

      DO Y = 1, N
        DO X = 1,N
          SPIN_A(Y,X) = SPIN_B(Y,X)
        ENDDO
      ENDDO

      END

!     SET ALPHA
      DOUBLE PRECISION FUNCTION SETALPHA(KT_INIT, KT_FIN, N_STEP)
      IMPLICIT NONE
      REAL*8 KT_INIT, KT_FIN, X1, X2, X12, F1, F2, F12, CONST
      INTEGER I, N_STEP, MAXI

      REAL*8,PARAMETER::EPSILON = 1E-5

      MAXI = 10000

      CONST = LOG(KT_FIN / KT_INIT) / REAL(N_STEP)
!     PRINT *, "CONST", CONST

      X1 = 0.1D0
      X2 = 1.0D0
      F1 = LOG(X1) - CONST
      F2 = LOG(X2) - CONST

!     PRINT * ,F1, F2

      DO I = 1, MAXI
        X12 = (X1 + X2) * 0.5D0
!       PRINT * , X12
        F12 = X12 * LOG(X12) - CONST
!       PRINT * , F12

        IF(ABS(F12) < EPSILON) THEN
          SETALPHA = X12
          RETURN
        ENDIF

        IF(F12 < 0) THEN
          X1 = X12
        ELSE
          X2 = X12
        ENDIF
!       PRINT * ,"X12", X12
      ENDDO
      END

      SUBROUTINE SPNDAT(T,SPIN,N,EN)
      IMPLICIT NONE
      CHARACTER*10 NAM
      INTEGER T,IX, IY, N
      REAL*8 SPIN(N,N),EN
      INTEGER, PARAMETER::IW = 5000
c
c     スピン配置SPINを行列の形で外部ファイルspin.datに書き出す
c     サイトの平均エネルギーENを外部ファイルen.datに書き出す
c
c
c     T (INTEGER)        : 現在I回目の呼び出し(I番目のスピン配置とエネルギーに
c                          ついてデータを書き足す)
c     SPIN(N,N) (REAL*8) : I番目のx,y座標のスピンの情報, SPIN(x,y) = 1.0d0 or -1.0d0
c     N (INTEGER)        : 二次元イジングの一辺のサイト数(合計スピン数はN*N)
c     EN (REAL*8)        : I番目のスピン配置に対応するエネルギー

c     T = -1のとき、ファイルの初期化を行う
      IF(T.EQ.-1) THEN
        OPEN(IW,FILE="spin.dat",STATUS="REPLACE")
        CLOSE(IW)
        OPEN(IW,FILE="en.dat",STATUS="REPLACE")
        WRITE(IW,*) "# Time        Energy"
        CLOSE(IW)
      ELSE
        OPEN(IW,FILE="spin.dat",STATUS="OLD",POSITION="APPEND")
        DO IY = 1, N
          DO IX = 1, N
            WRITE(IW,FMT='(I4, I4, 1X, F3.0)') IX, IY, SPIN(IX,IY)
          ENDDO
          ! 改行
          WRITE(IW,*)
        ENDDO
        CLOSE(IW)

        OPEN(IW,FILE="en.dat",STATUS="OLD",POSITION="APPEND")
        WRITE(IW,*) T, EN/(N**2)
        CLOSE(IW)
      ENDIF
      END
