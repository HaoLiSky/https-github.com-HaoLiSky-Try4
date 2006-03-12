!-----------------------------------------------------------------------------------!
! Bader charge density analysis program
!  Module for analyzing the charge with a voronoi analysis
!
! By Andri Arnaldsson and Graeme Henkelman
! Last modified by 
!
!-----------------------------------------------------------------------------------!
MODULE voronoi
  USE vars , ONLY : q2
  USE matrix
  IMPLICIT NONE

! Public, allocatable variables
  REAL(q2),ALLOCATABLE,DIMENSION(:,:) :: voronoi_charge

  INTEGER :: ndim,bdim,nrho,wdim

  PRIVATE
  PUBLIC :: voronoi
  CONTAINS

!-----------------------------------------------------------------------------------!
!  vornoi:  Calculate the charge density populations based upon Vornoi polyhedia.
!    In this scheme each element of charge density is associated with the atom that
!    it is closest to.
!-----------------------------------------------------------------------------------!
  SUBROUTINE voronoi()

    REAL(q2),DIMENSION(ndim,3) :: Ratm
    REAL(q2),DIMENSION(3) :: Rcur,dR,ngf,ngf_2
    REAL(q2) :: dist,min_dist,shift
    INTEGER :: i,nx,ny,nz,closest,tenths_done,cr,count_max,t1,t2

    CALL system_clock(t1,cr,count_max)

    WRITE(*,'(/,2x,A)') 'CALCULATING VORONOI CHARGE DISTRIBUTION'
    WRITE(*,'(2x,A)')   '               0  10  25  50  75  100'
    WRITE(*,'(2x,A,$)') 'PERCENT DONE:  **'

    wdim=ndim
    ALLOCATE(voronoi_charge(wdim,4))

    ngf(1)=REAL(ngxf,q2)
    ngf(2)=REAL(ngyf,q2)
    ngf(3)=REAL(ngzf,q2)
    ngf_2=REAL(ngf,q2)/2.0_q2

    shift=0.5_q2
    IF (vasp) shift=1.0_q2

    Ratm(:,1)=Rdir(:,1)*ngf(1)+shift
    Ratm(:,2)=Rdir(:,2)*ngf(2)+shift
    Ratm(:,3)=Rdir(:,3)*ngf(3)+shift

    voronoi_charge=0.0_q2
    tenths_done=0
    DO nx=1,ngxf
      Rcur(1)=REAL(nx,q2)
      IF ((nx*10/ngxf) > tenths_done) THEN
        tenths_done=(nx*10/ngxf)
!        WRITE(*,'(1X,1I4,1A6)') (tenths_done*10),'% done'
        WRITE(*,'(A,$)') '**'
      END IF
      DO ny=1,ngyf
        Rcur(2)=REAL(ny,q2)
        DO nz=1,ngzf
          Rcur(3)=REAL(nz,q2)
          closest=1
          dR=Rcur-Ratm(1,:)
          CALL dpbc(dR,ngf,ngf_2)
          min_dist=DOT_PRODUCT(dR,dR)
          DO i=2,wdim
            dR=Rcur-Ratm(i,:)
            CALL dpbc(dR,ngf,ngf_2)
            dist=DOT_PRODUCT(dR,dR)
            IF (dist < min_dist) THEN
              min_dist=dist
              closest=i
            END IF
          END DO
          voronoi_charge(closest,4)=voronoi_charge(closest,4)+                    &
                               rho_value(nx,ny,nz,ngxf,ngyf,ngzf)
        END DO
      END DO
    END DO
    WRITE(*,*)
! Don't have this normalization for MONDO
    voronoi_charge(:,4)=voronoi_charge(:,4)/REAL(nrho,q2)
    voronoi_charge(:,1:3)=Rcar

    CALL system_clock(t2,cr,count_max)
    WRITE(*,'(1A12,1F6.2,1A8)') 'RUN TIME: ',(t2-t1)/REAL(cr,q2),' SECONDS'

  RETURN
  END SUBROUTINE voronoi

!-----------------------------------------------------------------------------------!

END MODULE voronoi