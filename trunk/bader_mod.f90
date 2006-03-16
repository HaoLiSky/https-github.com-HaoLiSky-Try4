!-----------------------------------------------------------------------------------!
! Bader charge density analysis program
!  Module for analyzing the charge with the Bader atom in molecules approach
!
! By Andri Arnaldsson and Graeme Henkelman
! Last modified by 
!-----------------------------------------------------------------------------------!
MODULE bader_mod
  USE kind_mod , ONLY : q2
  USE matrix_mod
  USE options_mod
  USE ions_mod
  USE charge_mod
  USE io_mod
  IMPLICIT NONE

! Public parameters

! volnum: Bader volume number for each grid point
! volpos: position of maximum in each Bader volume
! colchg: integrated charge of each Bader volume
! ionchg: integrated charge over all Bader volumes associated with each ion
! iondist: distance from each Bader maximum to the nearest ion
! nnion: index of the nearst ion used to calculate iondist
! path: array of points along the current charge density maximization
! minsurfdist: minimum distance from the Bader surface to the included ion

! Public, allocatable variables
  TYPE bader_obj
    REAL(q2) :: tol
    INTEGER,ALLOCATABLE,DIMENSION(:,:,:) :: volnum
    REAL(q2),ALLOCATABLE,DIMENSION(:,:) :: volpos
    REAL(q2),ALLOCATABLE,DIMENSION(:) :: volchg,iondist,ionchg,minsurfdist
    INTEGER,ALLOCATABLE,DIMENSION(:) :: nnion
!    INTEGER,ALLOCATABLE,DIMENSION(:) :: num_atom,addup
    INTEGER nvols
  END TYPE

  INTEGER,ALLOCATABLE,DIMENSION(:,:) :: path

  PRIVATE
  PUBLIC :: bader_obj
  PUBLIC :: bader_calc,bader_mindist,bader_output

  CONTAINS
!-----------------------------------------------------------------------------------!
! bader_calc: Calculate the Bader volumes and integrate to give the total charge
!   in each volume.
!-----------------------------------------------------------------------------------!
  SUBROUTINE bader_calc(bdr,ions,chg,tol)

    TYPE(bader_obj) :: bdr
    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg
    REAL(q2) :: tol

    REAL(q2),ALLOCATABLE,DIMENSION(:,:) :: tmpvolpos
    REAL(q2),DIMENSION(3,3) :: B
    REAL(q2),DIMENSION(3) :: v,rnf
    INTEGER :: nx,ny,nz,px,py,pz,i,known_max,p,tenths_done
    INTEGER :: pdim,pnum,bdim,bnum,nxf,nyf,nzf
    INTEGER :: cr,count_max,t1,t2

    CALL system_clock(t1,cr,count_max)

    WRITE(*,'(/,2x,A)')   'CALCULATING BADER CHARGE DISTRIBUTION'
    WRITE(*,'(2x,A)')   '               0  10  25  50  75  100'
    WRITE(*,'(2x,A,$)') 'PERCENT DONE:  **'
    nxf=chg%nxf
    nyf=chg%nyf
    nzf=chg%nzf
    bdim=64  ! temporary number of bader volumes, will be expanded as needed
    pdim=64  ! temporary path length, also expanded as needed
    ALLOCATE(bdr%volpos(bdim,3))
    ALLOCATE(path(pdim,3))
    ALLOCATE(bdr%volnum(nxf,nyf,nzf))
    bdr%tol=tol
    bdr%volchg=0.0_q2
    bdr%volnum=0
    bnum=0
    bdr%nvols=0  ! True number of Bader volumes
    tenths_done=0
    DO nx=1,nxf
      IF ((nx*10/nxf) > tenths_done) THEN
        tenths_done=(nx*10/nxf)
        WRITE(*,'(A,$)') '**'
      END IF
      DO ny=1,nyf
        DO nz=1,nzf
          px=nx
          py=ny
          pz=nz
          IF(bdr%volnum(px,py,pz) == 0) THEN
            CALL maximize(bdr,chg,px,py,pz,pdim,pnum)
            CALL pbc(px,py,pz,nxf,nyf,nzf)  ! shouldn't need this
            known_max=bdr%volnum(px,py,pz)
            IF (known_max == 0) THEN
              bnum=bnum+1
              known_max=bnum
              IF (bnum > bdim) THEN
                ALLOCATE(tmpvolpos(bdim,3))
                tmpvolpos=bdr%volpos
                DEALLOCATE(bdr%volpos)
                bdim=2*bdim
                ALLOCATE(bdr%volpos(bdim,3))
!                bdr%volpos=0.0_q2
                bdr%volpos(1:bnum-1,:)=tmpvolpos
                DEALLOCATE(tmpvolpos)
              END IF
              bdr%volpos(bnum,:)=(/REAL(px,q2),REAL(py,q2),REAL(pz,q2)/)
            END IF
            DO p=1,pnum
              bdr%volnum(path(p,1),path(p,2),path(p,3))=known_max
            END DO
          END IF
        END DO
      END DO
    END DO
    WRITE(*,*)

!    write(*,*) sum(bdr%volchg)/chg%nrho
!    pause

! Sum up the charge included in each volume
    bdr%nvols=bnum
    ALLOCATE(bdr%volchg(bdr%nvols))
    bdr%volchg=0.0_q2
    DO nx=1,nxf
      DO ny=1,nyf
        DO nz=1,nzf
          bdr%volchg(bdr%volnum(nx,ny,nz))=bdr%volchg(bdr%volnum(nx,ny,nz))+chg%rho(nx,ny,nz)
        END DO
      END DO
    END DO

!    write(*,*) sum(bdr%volchg)/chg%nrho
!    pause

    ALLOCATE(tmpvolpos(bdim,3))
    tmpvolpos=bdr%volpos
    DEALLOCATE(bdr%volpos)
    ALLOCATE(bdr%volpos(bdr%nvols,3))
    bdr%volpos=tmpvolpos(1:bdr%nvols,:)
    DEALLOCATE(tmpvolpos)
!    bdim=bnum

!    write(*,*) 'nvols ',bdr%nvols

    ALLOCATE(bdr%nnion(bdr%nvols),bdr%iondist(bdr%nvols),bdr%ionchg(ions%nions))

! Don't have this normalization in MONDO
    bdr%volchg=bdr%volchg/REAL(chg%nrho,q2)

    rnf(1)=REAL(nxf,q2)
    rnf(2)=REAL(nyf,q2)
    rnf(3)=REAL(nzf,q2)
    DO i=1,bdr%nvols
      bdr%volpos(i,:)=(bdr%volpos(i,:)-1.0_q2)/rnf
    END DO

    CALL charge2atom(bdr,ions,chg)

    CALL transpose_matrix(ions%lattice,B,3,3)
    DO i=1,bdr%nvols
      CALL matrix_vector(B,bdr%volpos(i,:),v,3,3)
      bdr%volpos(i,:)=v
    END DO

    CALL system_clock(t2,cr,count_max)
    WRITE(*,'(1A12,1F6.2,1A8)') 'RUN TIME: ',(t2-t1)/REAL(cr,q2),' SECONDS'

  RETURN
  END SUBROUTINE bader_calc

!-----------------------------------------------------------------------------------!
! maximize:  From the point (px,py,pz) do a maximization on the charge density grid
!   and assign the maximum found to the volnum array.
!-----------------------------------------------------------------------------------!
  SUBROUTINE maximize(bdr,chg,px,py,pz,pdim,pnum)

    TYPE(bader_obj) :: bdr
    TYPE(charge_obj) :: chg
    INTEGER,INTENT(INOUT) :: px,py,pz,pdim,pnum

    INTEGER,ALLOCATABLE,DIMENSION(:,:) :: tmp
    INTEGER :: nxf,nyf,nzf

    nxf=chg%nxf
    nyf=chg%nyf
    nzf=chg%nzf

    pnum=1
    path(pnum,1:3)=(/px,py,pz/)
    DO
      IF(max_neighbour(chg,px,py,pz)) THEN
        pnum=pnum+1
        IF (pnum > pdim) THEN
          ALLOCATE(tmp(pdim,3))
          tmp=path
          DEALLOCATE(path)
          pdim=2*pdim
          ALLOCATE(path(pdim,3))
          path=0.0_q2
          path(1:pnum-1,:)=tmp
          DEALLOCATE(tmp)
        END IF
        CALL pbc(px,py,pz,nxf,nyf,nzf)
        path(pnum,1:3)=(/px,py,pz/)
        IF(bdr%volnum(px,py,pz) /= 0) EXIT
      ELSE
        EXIT
      END IF
    END DO

  RETURN
  END SUBROUTINE maximize

!-----------------------------------------------------------------------------------!
!  max_neighbour:  Do a single iteration of a maximization on the charge density 
!    grid from the point (px,py,pz).  Return a logical indicating if the current
!    point is a charge density maximum.
!-----------------------------------------------------------------------------------!

  FUNCTION max_neighbour(chg,px,py,pz)

    TYPE(charge_obj) :: chg
    INTEGER,INTENT(INOUT) :: px,py,pz
    LOGICAL :: max_neighbour

    REAL(q2) :: rho_max,rho_tmp,rho_ctr
    INTEGER :: dx,dy,dz,pxt,pyt,pzt,pxm,pym,pzm
    REAL(q2),DIMENSION(-1:1,-1:1,-1:1),SAVE :: w=RESHAPE((/           &
    &    0.5773502691896_q2,0.7071067811865_q2,0.5773502691896_q2,    &
    &    0.7071067811865_q2,1.0000000000000_q2,0.7071067811865_q2,    &
    &    0.5773502691896_q2,0.7071067811865_q2,0.5773502691896_q2,    &
    &    0.7071067811865_q2,1.0000000000000_q2,0.7071067811865_q2,    &
    &    1.0000000000000_q2,0.0000000000000_q2,1.0000000000000_q2,    &
    &    0.7071067811865_q2,1.0000000000000_q2,0.7071067811865_q2,    &
    &    0.5773502691896_q2,0.7071067811865_q2,0.5773502691896_q2,    &
    &    0.7071067811865_q2,1.0000000000000_q2,0.7071067811865_q2,    &
    &    0.5773502691896_q2,0.7071067811865_q2,0.5773502691896_q2     &
    &    /),(/3,3,3/))

    rho_max=0.0_q2
    pxm=px
    pym=py
    pzm=pz
    rho_ctr=rho_val(chg,px,py,pz)
    DO dx=-1,1
      pxt=px+dx
      DO dy=-1,1
        pyt=py+dy
        DO dz=-1,1
          pzt=pz+dz
          rho_tmp=rho_val(chg,pxt,pyt,pzt)
          rho_tmp=rho_ctr+w(dx,dy,dz)*(rho_tmp-rho_ctr)
          IF (rho_tmp > rho_max) THEN
            rho_max=rho_tmp
            pxm=pxt
            pym=pyt
            pzm=pzt
          END IF
        END DO
      END DO
    END DO

    max_neighbour=((pxm /= px) .or. (pym /= py) .or. (pzm /= pz))
    IF (max_neighbour) THEN
      px=pxm
      py=pym
      pz=pzm
    END IF

  RETURN
  END FUNCTION max_neighbour

!-----------------------------------------------------------------------------------!
! charge2atom: Assign an element of charge to a Bader atom.
!-----------------------------------------------------------------------------------!

  SUBROUTINE charge2atom(bdr,ions,chg)

    TYPE(bader_obj) :: bdr
    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg

    REAL(q2),DIMENSION(3,3) :: B
    REAL(q2),DIMENSION(3) :: dv,v
    REAL(q2) :: dsq,dminsq
    INTEGER :: i,j,dindex

    bdr%ionchg=0.0_q2
    CALL transpose_matrix(ions%lattice,B,3,3)
    DO i=1,bdr%nvols

!      write(*,*) i,bdr%volchg(i)

      dv=bdr%volpos(i,:)-ions%r_dir(1,:)
      CALL dpbc_dir(dv)
      CALL matrix_vector(B,dv,v,3,3)
      dminsq=DOT_PRODUCT(v,v)
      dindex=1
      DO j=2,ions%nions
        dv=bdr%volpos(i,:)-ions%r_dir(j,:)
        CALL dpbc_dir(dv)
        CALL matrix_vector(B,dv,v,3,3)
        dsq=DOT_PRODUCT(v,v)
        IF (dsq < dminsq) THEN
          dminsq=dsq
          dindex=j
        END IF
      END DO
      bdr%iondist(i)=SQRT(dminsq)
      bdr%nnion(i)=dindex
      bdr%ionchg(dindex)=bdr%ionchg(dindex)+bdr%volchg(i)
    END DO
 
!    write(*,*) sum(bdr%volchg)
!    pause
 
!    write(*,*) bdr%ionchg
!    pause
  
  RETURN
  END SUBROUTINE charge2atom

!-----------------------------------------------------------------------------------!
! bader_mindist: Find the minimum distance from the surface of each volume to 
!-----------------------------------------------------------------------------------!

  SUBROUTINE bader_mindist(bdr,ions,chg)

    TYPE(bader_obj) :: bdr
    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg

    REAL(q2),DIMENSION(3,3) :: B
    REAL(q2),DIMENSION(3) :: dv,v,ringf,shift
    REAL :: dist
    INTEGER :: i,atom,atom_tmp,nx,ny,nz,tenths_done
    INTEGER :: cr,count_max,t1,t2,nxf,nyf,nzf
    INTEGER :: dx,dy,dz,nxt,nyt,nzt
    LOGICAL :: surfflag

    nxf=chg%nxf
    nyf=chg%nyf
    nzf=chg%nzf
 
    CALL system_clock(t1,cr,count_max)

    WRITE(*,'(/,2x,A)') 'CALCULATING MINIMUM DISTANCES TO ATOMS'
    WRITE(*,'(2x,A)')   '               0  10  25  50  75  100'
    WRITE(*,'(2x,A,$)') 'PERCENT DONE:  **'

!   Store the minimum distance and the vector
    ALLOCATE(bdr%minsurfdist(ions%nions))
    bdr%minsurfdist=0.0_q2
    IF (chg%halfstep) THEN
      shift=0.5_q2               ! Gaussian style
    ELSE
      shift=1.0_q2               ! VASP style 
    END IF

    ringf(1)=1.0_q2/REAL(nxf,q2)
    ringf(2)=1.0_q2/REAL(nyf,q2)
    ringf(3)=1.0_q2/REAL(nzf,q2)
    tenths_done=0
    DO nx=1,nxf
      IF ((nx*10/nxf) > tenths_done) THEN
        tenths_done=(nx*10/nxf)
        WRITE(*,'(A,$)') '**'
      END IF
      DO ny=1,nyf
        DO nz=1,nzf

!         Check to see if this is at the edge of an atomic volume
          atom=bdr%nnion(bdr%volnum(nx,ny,nz))
          surfflag=.FALSE.
          neighbourloop: DO dx=-1,1
            nxt=nx+dx
            DO dy=-1,1
              nyt=ny+dy
              DO dz=-1,1
                nzt=nz+dz
                CALL pbc(nxt,nyt,nzt,nxf,nyf,nzf)
                atom_tmp=bdr%nnion(bdr%volnum(nxt,nyt,nzt))
                IF (atom_tmp /= atom ) THEN
                  surfflag=.TRUE.
                  EXIT neighbourloop
                END IF
              END DO
            END DO
          END DO neighbourloop

!         If this is an edge cell, check if it is the closest to the atom so far
          IF (surfflag) THEN
            v(1:3)=(/nx,ny,nz/)
            dv=(v-shift)*ringf-ions%r_dir(atom,:)
            CALL dpbc_dir(dv)
            dist=DOT_PRODUCT(dv,dv)
            IF ((bdr%minsurfdist(atom) == 0.0_q2) .OR. (dist < bdr%minsurfdist(atom))) THEN
              bdr%minsurfdist(atom)=dist
            END IF
          END IF

        END DO
      END DO
    END DO

!    CALL transpose_matrix(ions%lattice,B,3,3)
!    DO i=1,ions%nions 
!      CALL matrix_vector(B,bdr%minsurfdist(i,1:3),v,3,3)
!      minsurfdist(i,1:3)=v
!      minsurfdist(i,4)=sqrt(DOT_PRODUCT(v,v))
!!      write(*,*) minsurfdist(i,4)
!    END DO

    WRITE(*,*)
    CALL system_clock(t2,cr,count_max)
    WRITE(*,'(1A12,1F6.2,1A8)') 'RUN TIME: ',(t2-t1)/REAL(cr,q2),' SECONDS'
  
  RETURN
  END SUBROUTINE bader_mindist

!------------------------------------------------------------------------------------!
! write_volnum: Write out a CHGCAR type file with each entry containing an integer
!    indicating the associated Bader maximum.
!------------------------------------------------------------------------------------!

  SUBROUTINE write_volnum(bdr,opts,ions,chg)

     TYPE(bader_obj) :: bdr
     TYPE(options_obj) :: opts
     TYPE(ions_obj) :: ions
     TYPE(charge_obj) :: chg

     TYPE(charge_obj) :: tmp
     INTEGER :: nx,ny,nz
     CHARACTER(LEN=120) :: filename

     tmp=chg
     tmp%rho=bdr%volnum
     
     filename='VOLUME_INDEX'
     CALL write_charge(ions,chg,opts,filename)

  RETURN
  END SUBROUTINE write_volnum

!------------------------------------------------------------------------------------!
! write_all_bader: Write out a CHGCAR type file for each of the Bader volumes found.
!------------------------------------------------------------------------------------!

  SUBROUTINE write_all_bader(bdr,opts,ions,chg)

    TYPE(bader_obj) :: bdr
    TYPE(options_obj) :: opts
    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg

    TYPE(charge_obj) :: tmp
    INTEGER :: nx,ny,nz,i,atomnum,badercur,tenths_done,t1,t2,cr,count_max
    CHARACTER(LEN=120) :: atomfilename,atomnumtext
    
    tmp=chg

    WRITE(*,'(/,2x,A)') 'WRITING BADER VOLUMES'
    WRITE(*,'(2x,A)')   '               0  10  25  50  75  100'
    WRITE(*,'(2x,A,$)') 'PERCENT DONE:  **'
    CALL system_clock(t1,cr,count_max)
    atomnum=0
    tenths_done=0

!    bdr%tol=1.0e-4_q2
    DO badercur=1,bdr%nvols
      DO WHILE ((badercur*10/bdr%nvols) > tenths_done)
        tenths_done=tenths_done+1
        WRITE(*,'(A,$)') '**'
      ENDDO
      IF(bdr%volchg(badercur) > bdr%tol) THEN
        atomnum=atomnum+1
        IF(atomnum<10) THEN
          WRITE(atomnumtext,'(1A3,I1)') '000',atomnum
        ELSE IF(atomnum<100) THEN
          WRITE(atomnumtext,'(1A2,I2)') '00',atomnum
        ELSE IF(atomnum<1000) THEN
          WRITE(atomnumtext,'(1A1,I3)') '0',atomnum
        ELSE
          WRITE(atomnumtext,'(I4)') atomnum
        END IF
        atomfilename = "Bvol"//Trim(atomnumtext(1:))//".dat"

        tmp%rho=0.0_q2
        WHERE(bdr%volnum == badercur) tmp%rho=chg%rho
        CALL write_charge(ions,chg,opts,atomfilename)

      END IF
    END DO

    DEALLOCATE(tmp%rho)

    CALL system_clock(t2,cr,count_max)
    WRITE(*,'(/,1A12,1F6.2,1A8,/)') 'RUN TIME: ',(t2-t1)/REAL(cr,q2),' SECONDS'

  RETURN
  END SUBROUTINE write_all_bader

!------------------------------------------------------------------------------------!
! write_all_atom: Write out a CHGCAR type file for each atom where all Bader volumes
!              assigned to that atom are added together. This is only done if the 
!              atoms has any 'significant' bader volumes associated with it.
!------------------------------------------------------------------------------------!

  SUBROUTINE write_all_atom(bdr,opts,ions,chg)

    TYPE(bader_obj) :: bdr
    TYPE(options_obj) :: opts
    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg

    TYPE(charge_obj) :: tmp

    INTEGER :: nx,ny,nz,i,j,b,mab,mib,ik,sc,cc,tenths_done,t1,t2,cr,count_max
    INTEGER,DIMENSION(bdr%nvols) :: rck
    CHARACTER(LEN=120) :: atomfilename,atomnumtext

    CALL system_clock(t1,cr,count_max)

    tmp=chg

    WRITE(*,'(/,2x,A)') 'WRITING BADER VOLUMES '
    WRITE(*,'(2x,A)')   '               0  10  25  50  75  100'
    WRITE(*,'(2x,A,$)') 'PERCENT DONE:  **'
    tenths_done=0
    mab=MAXVAL(bdr%nnion)
    mib=MINVAL(bdr%nnion)
    sc=0

!    bdr%tol=1.0e-4_q2
    DO ik=mib,mab
      cc=0
      rck=0
      DO j=1,bdr%nvols
        IF (bdr%volchg(j) < bdr%tol) CYCLE
        IF (bdr%nnion(j) == ik) THEN
          cc=cc+1
          rck(cc)=j
        END IF
      END DO
      sc=sc+cc
      DO WHILE ((ik*10/(mab-mib+1)) > tenths_done)
        tenths_done=tenths_done+1
        WRITE(*,'(A,$)') '**'
      END DO
      IF(cc == 0) CYCLE
      IF(ik < 10) THEN
        WRITE(atomnumtext,'(1A3,I1)') '000',ik
      ELSE IF(ik<100) THEN
        WRITE(atomnumtext,'(1A2,I2)') '00',ik
      ELSE IF(ik<1000) THEN
        WRITE(atomnumtext,'(1A1,I3)') '0',ik
      ELSE
        WRITE(atomnumtext,'(I4)') ik
      END IF
      atomfilename = "BvAt"//Trim(atomnumtext(1:))//".dat"

      tmp%rho=0.0_q2
      DO b=1,cc
        WHERE(bdr%volnum == rck(b)) tmp%rho=chg%rho
      END DO 
      CALL write_charge(ions,chg,opts,atomfilename)

    END DO
    DEALLOCATE(tmp%rho)

    CALL system_clock(t2,cr,count_max)
    WRITE(*,'(/,1A12,1F6.2,1A8,/)') 'RUN TIME: ',(t2-t1)/REAL(cr,q2),' SECONDS'

  RETURN
  END SUBROUTINE write_all_atom

!------------------------------------------------------------------------------------!
! write_sel_bader: Write out a CHGCAR type file for specified Bader volumes by the user.
!              Volumes associated with a atom can be read from AtomVolumes.dat
!------------------------------------------------------------------------------------!

  SUBROUTINE write_sel_bader(bdr,opts,ions,chg)

    TYPE(bader_obj) :: bdr
    TYPE(options_obj) :: opts
    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg

    TYPE(charge_obj) :: tmp
    CHARACTER(LEN=120) :: atomfilename
    INTEGER,DIMENSION(bdr%nvols,2) :: volsig
!    INTEGER,DIMENSION(na) :: vols
    INTEGER :: cr,count_max,t1,t2,i,bdimsig

    CALL system_clock(t1,cr,count_max)

    tmp=chg

! Correlate the number for each 'significant' bader volume to its real number
    bdimsig=0
    volsig=0

!    bdr%tol=1.0e-4_q2
    DO i=1,bdr%nvols
      IF (bdr%volchg(i) > bdr%tol) THEN
        bdimsig=bdimsig+1
        volsig(bdimsig,1)=bdimsig
        volsig(bdimsig,2)=i
      END IF
    END DO
!    vols=volsig(addup,2)
    WRITE(*,'(/,2x,A)') 'WRITING SPECIFIED BADER VOLUMES '
    atomfilename = "Bvsm.dat"

    tmp%rho=0.0_q2
! fix this when we get na input through options
!    DO b=1,na
!      WHERE(bdr%volnum == vols(b)) tmp%rho=chg%rho
!    END DO
    CALL write_charge(ions,chg,opts,atomfilename)

    DEALLOCATE(tmp%rho)

    CALL system_clock(t2,cr,count_max)
    WRITE(*,'(1A12,1F6.2,1A8,/)') 'RUN TIME: ',(t2-t1)/REAL(cr,q2),' SECONDS'

  RETURN
  END SUBROUTINE write_sel_bader

!------------------------------------------------------------------------------------!
! bader_output: Write out a summary of the bader analysis.
!         AtomVolumes.dat: Stores the 'significant' Bader volumes associated with
!                          each atom.
!         ACF.dat        : Stores the main output to the screen.
!         BCF.dat        : Stores 'significant' Bader volumes, their coordinates and
!                          charge, atom associated and distance to it. 
!------------------------------------------------------------------------------------!

  SUBROUTINE bader_output(bdr,ions,chg)

    TYPE(bader_obj) :: bdr
    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg

  
    REAL(q2) :: sum_ionchg
    INTEGER :: i,bdimsig,mib,mab,cc,j,nmax
    INTEGER,DIMENSION(bdr%nvols) :: rck
  
    mab=MAXVAL(bdr%nnion)
    mib=MINVAL(bdr%nnion)
    OPEN(100,FILE='AVF.dat',STATUS='replace',ACTION='write')
    WRITE(100,'(A)') '   Atom                     Volume(s)   '
    WRITE(100,'(A,A)') '-----------------------------------------------------------',&
  &                    '-------------'

!    bdr%tol=1.0e-4_q2
    DO i=mib,mab
      cc=0
      rck=0
      nmax=0
      DO j=1,bdr%nvols
        IF (bdr%volchg(j) > bdr%tol) THEN
          nmax=nmax+1
          IF(bdr%nnion(j) == i) THEN
            cc=cc+1
            rck(cc)=nmax
          END IF
        END IF
      END DO 
      IF (cc == 0) CYCLE
      WRITE(100,'(2X,1I4,2X,A,2X,10000I5)') i,' ... ',rck(1:cc)
    END DO
    CLOSE(100)
    
    WRITE(*,'(/,A41)') 'WRITING BADER ATOMIC CHARGES TO ACF.dat'
    WRITE(*,'(A41,/)') 'WRITING BADER VOLUME CHARGES TO BCF.dat'

    OPEN(100,FILE='ACF.dat',STATUS='replace',ACTION='write')
!old    WRITE(*,555) '#','X','Y','Z','VORONOI','BADER','%','MIN DIST'
!old    WRITE(100,555) '#','X','Y','Z','VORONOI','BADER','%','MIN DIST'
!    WRITE(*,555) '#','X','Y','Z','BADER','MIN DIST'
    WRITE(100,555) '#','X','Y','Z','BADER','MIN DIST'
!old    555 FORMAT(/,4X,1A,9X,1A1,2(11X,1A1),8X,1A7,5X,1A5,9X,1A1,6X,1A10)
    555 FORMAT(4X,1A,9X,1A1,2(11X,1A1),8X,1A5,6X,1A8)
!    WRITE(*,666)   '----------------------------------------------------------------'
    WRITE(100,666) '----------------------------------------------------------------'
    666 FORMAT(1A66)
    
    sum_ionchg=SUM(bdr%ionchg)
    DO i=1,ions%nions


!old      WRITE(*,'(1I5,7F12.4)') i,ions%r_car(i,:),vor%vorchg(i),bdr%ionchg(i),         &
!  &                           100.*bdr%ionchg(i)/sum_ionchg,bdr%minsurfdist(i)
!old      WRITE(100,'(1I5,7F12.4)') i,ions%r_car(i,:),vor%vorchg(i),bdr%ionchg(i),       &
!  &                           100.*bdr%ionchg(i)/sum_ionchg,bdr%minsurfdist(i)
!      WRITE(*,'(1I5,6F12.4)') i,ions%r_car(i,:),bdr%ionchg(i),bdr%minsurfdist(i)
      WRITE(100,'(1I5,6F12.4)') i,ions%r_car(i,:),bdr%ionchg(i),bdr%minsurfdist(i)
    END DO
    CLOSE(100)

    bdimsig=0
    OPEN(200,FILE='BCF.dat',STATUS='replace',ACTION='write')

    WRITE(200,556) '#','X','Y','Z','CHARGE','ATOM','DISTANCE'
    556 FORMAT(4X,1A1,9X,1A1,2(11X,1A1),8X,1A6,5X,1A4,4X,1A8)
    
    WRITE(200,668) '---------------------------------------------------------------',&
  &                '----------'
    668 FORMAT(1A65,1A10)
   
    write(*,*) bdr%tol 
    DO i=1,bdr%nvols
        IF(bdr%volchg(i) > bdr%tol) THEN
           bdimsig=bdimsig+1
           WRITE(200,777) bdimsig,bdr%volpos(i,:),bdr%volchg(i),bdr%nnion(i),bdr%iondist(i)
           777 FORMAT(1I5,4F12.4,3X,1I5,1F12.4)
        END IF
    END DO
    CLOSE(200)

!    OPEN(300,FILE='dipole.dat',STATUS='replace',ACTION='write')
!    WRITE(300,557) '#','X','Y','Z','MAGNITUDE'
!    557 FORMAT(/,4X,1A1,10X,1A1,2(15X,1A1),10X,1A10)
!    WRITE(300,*) '--------------------------------------------------------------------'
!    DO i=1,ndim
!      WRITE(300,888) i,dipole(i,:)*4.803_q2,                                         &
!  &                  sqrt(DOT_PRODUCT(dipole(i,:),dipole(i,:)))*4.803_q2
!!      888 FORMAT(1I5,4ES16.5)
!      888 FORMAT(1I5,4F16.6)
!    END DO
!    CLOSE(300)

    WRITE(*,'(/,2x,A,6X,1I8)')     'NUMBER OF BADER MAXIMA FOUND: ',bdr%nvols
    WRITE(*,'(2x,A,6X,1I8)')       '    SIGNIFICANT MAXIMA FOUND: ',bdimsig
    WRITE(*,'(2x,A,2X,1F12.5,/)')  '         NUMBER OF ELECTRONS: ',                 &
  &                                          SUM(bdr%volchg(1:bdr%nvols))

  RETURN
  END SUBROUTINE bader_output

!-----------------------------------------------------------------------------------!

END MODULE bader_mod
