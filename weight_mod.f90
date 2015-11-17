  !-----------------------------------------------------------------------------------!
  ! Bader charge density analysis program
  !  Module implementing the weight method by Yu and Trinkle [JCP 134, 064111 (2011)]
  !-----------------------------------------------------------------------------------!

  MODULE weight_mod

    USE kind_mod
    USE matrix_mod
    USE bader_mod
    USE charge_mod 
    USE options_mod
    USE ions_mod
    USE io_mod
    USE chgcar_mod
    IMPLICIT NONE
    PRIVATE

    TYPE weight_obj
      REAL(q2) :: rho
      INTEGER, DIMENSION(3) :: pos
      INTEGER ::  volnum  ! similar to bader volnum
    END TYPE

    TYPE rvert_obj
      REAL(q2), DIMENSION(3) :: r
      REAL(q2) :: phi
    END TYPE

    PUBLIC :: weight_obj
    PUBLIC :: bader_weight_calc

  CONTAINS

  SUBROUTINE bader_weight_calc(bdr, ions, chgval, opts)

    TYPE(bader_obj) :: bdr
    TYPE(ions_obj) :: ions, ionsref
    TYPE(charge_obj) :: chgval, chgref
    TYPE(options_obj) :: opts
    TYPE(weight_obj), ALLOCATABlE, DIMENSION(:) :: chgList
    TYPE(weight_obj) :: tempwobj
    INTEGER :: nPts, i, n, n1, n2, n3, numVect, nv
    INTEGER :: t1, t2, cr, cm, nabove, na, nb, tbasin, m
    REAL(q2) :: vol, tsum, tw, temp
    INTEGER, ALLOCATABLE, DIMENSION(:,:,:) :: indList
    INTEGER, ALLOCATABLE, DIMENSION(:,:) :: vect, neigh
    INTEGER, ALLOCATABLE, DIMENSION(:) :: numbelow, basin, above
    INTEGER, DIMENSION(3) :: p
    REAL(q2), ALLOCATABLE, DIMENSION(:) :: alpha
    REAL(q2), ALLOCATABLE, DIMENSION(:) :: t, w
    REAL(q2), ALLOCATABLE, DIMENSION(:,:) :: prob
    REAL(q2), DIMENSION(3,3) :: cell
    LOGICAL :: boundary

    ! above : an array of idecies of cells with higher rho
    ! tbasin : a temporary basin entry
    ! basin : an array used to store basin info of all neighbors with higher rho
    ! numbelow : 

    bdr%nvols = 0

    DO i=1,3
      cell(i,:) = ions%lattice(i,:)/chgval%npts(i)
    END DO

    CALL ws_voronoi(cell, numVect, vect, alpha)
    CALL SYSTEM_CLOCK(t1, cr, cm)

    IF (opts%ref_flag) THEN
      CALL read_charge_ref(ionsref, chgref, opts)
      ! Assert that chgval and chgref are of the same size
      IF ((chgval%npts(1) /= chgref%npts(1)) .OR. &
          (chgval%npts(2) /= chgref%npts(2)) .OR. &
          (chgval%npts(3) /= chgref%npts(3))) THEN
         WRITE(*,'(/,2x,A,/)') &
           'The dimensions of the primary and reference charge densities must be the same, stopping.'
         STOP
      END IF
    ELSE
      chgref = chgval
    END IF

    nPts = chgref%npts(1)*chgref%npts(2)*chgref%npts(3)
!    bdr%tol = opts%badertol  ! delete this?
    ALLOCATE (numbelow(nPts))
    ALLOCATE (w(nPts))
    ALLOCATE (neigh(nPts, numVect))
    ALLOCATE (prob(nPts, numVect))
    ALLOCATE (basin(nPts))
    ALLOCATE (chgList(nPts))
    ALLOCATE (bdr%volnum(chgref%npts(1), chgref%npts(2), chgref%npts(3)))
    ALLOCATE (indList(chgref%npts(1), chgref%npts(2), chgref%npts(3)))
    bdr%bdim = 64 ! will expand as needed
    ALLOCATE (bdr%volpos_lat(bdr%bdim, 3))

    ! Find vacuum points
    IF (opts%vac_flag) THEN
      DO n1 = 1,chgval%npts(1)
        DO n2 = 1,chgval%npts(2)
          DO n3 = 1,chgval%npts(3)
            IF (ABS(rho_val(chgval,n1,n2,n3)/vol) <= opts%vacval) THEN
               bdr%volnum(n1,n2,n3) = -1
               bdr%vacchg = bdr%vacchg + chgval%rho(n1,n2,n3)
               bdr%vacvol = bdr%vacvol + 1
            END IF
          END DO
        END DO
      END DO
    END IF
    bdr%vacchg = bdr%vacchg/REAL(chgval%nrho,q2)
    bdr%vacvol = bdr%vacvol*vol/chgval%nrho

    n = 1
    DO n1 = 1, chgref%npts(1)
      DO n2 = 1, chgref%npts(2)
        DO n3 = 1, chgref%npts(3)
          chgList(n)%rho = chgref%rho(n1,n2,n3)
          chgList(n)%pos = (/n1,n2,n3/)
          chgList(n)%volnum = 0
          n = n + 1
        END DO
      END DO
    END DO

    WRITE(*,'(/,2x,A,$)') 'SORTING CHARGE VALUES ... '
    CALL sort_weight(nPts, chgList) ! max value first

    DO n = 1, nPts
      indList(chgList(n)%pos(1), chgList(n)%pos(2), chgList(n)%pos(3)) = n
    END DO

    WRITE(*,'(A)'), 'DONE'

    ! first loop, deal with all interior points
    WRITE(*,'(2x,A,$)') 'CALCULATING FLUX ... '
    DO n1 = 1, nPts
      basin(n1) = 0
      numbelow(n1) = 0
      nabove = 0
      tsum = 0
      ALLOCATE (t(numVect))
      ALLOCATE (above(numVect))
      DO n2 = 1, numVect
        p = chgList(n1)%pos + vect(n2,:)
        CALL pbc(p, chgref%npts)
        m = indList(p(1), p(2), p(3))
        IF (m < n1 ) THEN ! point p has higher rho
          nabove = nabove + 1
          above(nabove) = m 
          t(nabove) = alpha(n2)*(chgList(m)%rho - chgList(n1)%rho)
          tsum = tsum + t(nabove)
        END IF
      END DO
      IF (nabove == 0) THEN ! maxima
        bdr%bnum = bdr%bnum + 1
        bdr%nvols = bdr%nvols + 1
        basin(n1) = bdr%nvols
        bdr%volnum(chgList(n1)%pos(1), chgList(n1)%pos(2), chgList(n1)%pos(3)) = bdr%nvols 
        IF (bdr%bnum >= bdr%bdim) THEN
          CALL reallocate_volpos(bdr, bdr%bdim*2)
        END IF
        DEALLOCATE(t)
        DEALLOCATE(above)
        bdr%volpos_lat(bdr%bnum,:) = REAL(p,q2)
        CYCLE
      END IF
      tbasin = basin(above(1))
      boundary = .FALSE.
      DO n2 = 1, nabove
        IF (basin(above(n2))/=tbasin .OR. tbasin==0) THEN 
          boundary = .TRUE.
        END IF
      END DO 
      IF (boundary) THEN ! boundary
        basin(n1) = 0
        temp = 0
        DO n2 = 1, nabove
          m = above(n2)
          numbelow(m) = numbelow(m) + 1
          neigh(m,numbelow(m)) = n1
          prob(m,numbelow(m)) = t(n2) / tsum
          IF (prob(m,numbelow(m)) > temp) THEN
            temp = prob(m,numbelow(m))
            bdr%volnum( chgList(n1)%pos(1), chgList(n1)%pos(2), chgList(n1)%pos(3)) = &
              bdr%volnum( chgList(m)%pos(1), chgList(m)%pos(2), chgList(m)%pos(3) )
          END IF
        END DO
      ELSE ! interior
        basin(n1) = tbasin
        bdr%volnum(chgList(n1)%pos(1), chgList(n1)%pos(2), chgList(n1)%pos(3)) = tbasin
      END IF
      DEALLOCATE(t)
      DEALLOCATE(above)
    END DO
    ! restore chglist rho to values from chgval
    DO n = 1, nPts
      chgList(n)%rho = chgval%rho(chgList(n)%pos(1), chgList(n)%pos(2), chgList(n)%pos(3))
    END DO
    WRITE(*,'(A)'), 'DONE'

    WRITE(*,'(2x,A,$)') 'INTEGRATING CHARGES ... '
    ALLOCATE (bdr%volchg(bdr%nvols))
    ALLOCATE (bdr%ionvol(bdr%nvols))
    DO n1 = 1,bdr%nvols
      bdr%volchg(n1) = 0
      bdr%ionvol(n1) = 0
    END DO
    ! bdr%volnum is written here during integration. so that each cell is
    ! assigned to the basin where it has most of the weight to. This should not
    ! affect the result of the integration.
    temp = 0
    DO n1 = 1, bdr%nvols
      DO n2 = 1, nPts
        IF (basin(n2) == n1) THEN
          w(n2) = 1
        ELSE
          w(n2) = 0
        END IF
      END DO
      DO n2 = 1, nPts
        tw = w(n2)
        IF (tw /= 0) THEN
          DO n = 1, numbelow(n2)
            w(neigh(n2, n)) = w(neigh(n2, n)) + prob(n2, n)*tw
          END DO
          bdr%volchg(n1) = bdr%volchg(n1) + tw * chgList(n2)%rho
          bdr%ionvol(n1) = bdr%ionvol(n1) + tw
        END IF
      END DO
    END DO
    bdr%volchg = bdr%volchg / REAL(chgval%nrho,q2)
    WRITE(*,'(A)'), 'DONE'

    vol = matrix_volume(ions%lattice)
    vol = vol/chgref%nrho
    bdr%ionvol = bdr%ionvol*vol

    CALL SYSTEM_CLOCK(t2, cr, cm)
    WRITE(*,'(/,1A12,1F10.2,1A8)') 'RUN TIME: ', (t2-t1)/REAL(cr,q2), ' SECONDS'

    DO n = 1, nPts
      IF (bdr%volnum(chgList(n)%pos(1), chgList(n)%pos(2), &
          chgList(n)%pos(3)) == 0) THEN
        PRINT *,'still zero'
      END IF
    END DO

    ALLOCATE (bdr%nnion(bdr%nvols))
    ALLOCATE (bdr%iondist(bdr%nvols))
    ALLOCATE (bdr%ionchg(ions%nions))
    ALLOCATE (bdr%volpos_dir(bdr%nvols, 3))
    ALLOCATE (bdr%volpos_car(bdr%nvols, 3))

    DO i = 1, bdr%nvols
      bdr%volpos_dir(i,:) = lat2dir(chgref, bdr%volpos_lat(i,:))
      bdr%volpos_car(i,:) = lat2car(chgref, bdr%volpos_lat(i,:))
    END DO

    CALL assign_chg2atom(bdr, ions, chgval)

    DEALLOCATE (numbelow)
    DEALLOCATE (w)
    DEALLOCATE (neigh)
    DEALLOCATE (prob)
    DEALLOCATE (chgList)
    DEALLOCATE (indList)
    DEALLOCATE (basin)

  END SUBROUTINE bader_weight_calc


  !-----------------------------------------------------------------------------------!
  !  Source:  adapted from ws_voronoi.H
  !  Author:  D. Trinkle
  !  Date:    2010 December 27
  !  Purpose: Determines the prefactors for computation of flux in Wigner-Seitz
  !           grid cells, based on the Voronoi decomposition.
  !-----------------------------------------------------------------------------------!

  SUBROUTINE ws_voronoi(cell, numVect, vect, alpha)

! Construct a list of the neighboring vectors that define the Wigner-Seitz cell
! and compute the "alpha" factors needed for flux; you multiply the difference
! in densities by alpha, and use this to compute the transition probabilities.

    REAL(q2), DIMENSION(3,3) :: cell
    INTEGER, INTENT(INOUT) :: numVect
    INTEGER, ALLOCATABLE, DIMENSION(:,:) :: vect
    REAL(q2), ALLOCATABLE, DIMENSION(:) :: alpha

    TYPE(rvert_obj), ALLOCATABLE, DIMENSION(:) :: rVert
    REAL(q2), ALLOCATABLE, DIMENSION(:,:) :: R, Rtmp
    REAL(q2), ALLOCATABLE, DIMENSION(:) :: alphtmp, Rmag, Rmagtmp
    REAL(q2), DIMENSION(3,3) :: Rdot, Radj
    REAL(q2), DIMENSION(3) :: neighR, R2, Rx, Ry, nv
    REAL(q2) :: detR, tol, temp, rdRn
    INTEGER, ALLOCATABLE, DIMENSION(:,:) :: nVect, nVecttmp
    INTEGER :: nv1, nv2, nv3, nA, nB, i, n, nvi
    INTEGER :: nRange, numVert, maxVert, neigh, numNeigh, maxNeigh
    LOGICAL :: prnt, zeroarea

! Generate a list of neighboring vectors that bound the Wigner-Seitz cell.
! Note for future: should precompute this by making a sphere of radius
! with the largest length vector multiplied by, say, 2.

    tol = 1E-8
    nRange = 3
    maxNeigh = (2*nRange + 1)**3 - 1

    ALLOCATE (nVect(maxNeigh,3), nVecttmp(maxNeigh,3))
    ALLOCATE (R(maxNeigh,3), Rtmp(maxNeigh,3))
    ALLOCATE (Rmag(maxNeigh), Rmagtmp(maxNeigh))

    neigh = 0
    DO nv1 = -nRange, nRange
      DO nv2 = -nRange,nRange
        DO nv3 = -nRange,nRange
          nv = (/nv1,nv2,nv3/)
          IF (ALL(nv == 0)) CYCLE
          neigh = neigh + 1
          nVect(neigh,:) = nv
          R(neigh,:) = MATMUL(cell, nv)
          Rmag(neigh) = SUM(R(neigh,:)*R(neigh,:))*0.5_q2
!          write(*,*) "neigh: ",neigh,"nVect ",nVect(neigh,:)
!          write(*,*) "R ",R(neigh,:)," Rmag ",Rmag(neigh)
        END DO
      END DO
    END DO

!    write(*,*) "maxNeigh: ", maxNeigh

    ! find the number of neighboring vectors in the WS cell, numNeigh
    numNeigh = 0
!    DO neigh = 1, maxNeigh
    DO neigh = maxNeigh, 1, -1
      ! check to see if R/2 is within the WS cell
      IF( incell(R(neigh,:)*0.5_q2, maxNeigh, R, Rmag, tol, .FALSE.) ) THEN
!        write(*,*) "neigh",neigh," incell"
        numNeigh = numNeigh + 1
        Rtmp(numNeigh,:) = R(neigh,:)
        Rmagtmp(numNeigh) = Rmag(neigh)
        nVecttmp(numNeigh,:) = nVect(neigh,:)
      END IF
    END DO

!    write(*,*) "numNeigh: ", numNeigh

    DEALLOCATE(R, Rmag, nVect)
    ALLOCATE(R(numNeigh,3), nVect(numNeigh,3), Rmag(numNeigh))
!    R(1:numNeigh,:) = Rtmp(1:numNeigh,:)
!    Rmag(1:numNeigh) = Rmagtmp(1:numNeigh)
!    nVect(1:numNeigh,:) = nVecttmp(1:numNeigh,:)
    DO neigh = 1, numNeigh
      R(NumNeigh+1 - neigh,:) = Rtmp(neigh,:)
      Rmag(NumNeigh+1 - neigh) = Rmagtmp(neigh)
      nVect(NumNeigh+1 - neigh,:) = nVecttmp(neigh,:)
    END DO
    DEALLOCATE(Rtmp, Rmagtmp, nVecttmp)

!    DO neigh = 1, numNeigh
!      write(*,*) "neigh: ",neigh," nVect: ",nVect(neigh,:)
!      write(*,*) "neigh: ",neigh," R: ",R(neigh,:)
!    END DO

    ! next step is to find all of the vertex points
    maxVert = (numNeigh-2)*(numNeigh-4)
    ALLOCATE (rVert(maxVert))
    ALLOCATE (alphtmp(numNeigh))
    numVect = numNeigh
    DO neigh = 1, numNeigh
      numVert = 1
      Rdot(1,:) = R(neigh,:)
      R2(1) = Rmag(neigh)
      DO nA = 1, numNeigh
        Rdot(2,:) = R(nA,:)
        R2(2) = Rmag(nA)
        DO nB = nA + 1, numNeigh
          Rdot(3,:) = R(nB,:)
          R2(3) = Rmag(nB)
          detR = determinant(Rdot) 
          Radj = adjoint(Rdot)

!          write(*,*) "Rdot: ",neigh," ",nA," ",nB
!          write(*,'(9F10.6)') Rdot(1,:),Rdot(2,:),Rdot(3,:)
!          write(*,'(A,F10.6)') "det: ",detR
!          write(*,'(A,9F10.6)') "Radj: ",Radj(1,:),Radj(2,:),Radj(3,:)
!          write(*,'(A,3F10.6)') "R2: ",R2(:)

          IF (ABS(detR) >= tol) THEN
            rVert(numVert)%r = MATMUL(Radj, R2)/detR
!             write(*,'(A,I4,A,3F10.6)') "rVert(",numVert,"): ",rVert(numVert)%r(:)
!            IF (ALL(nVect(neigh,:).EQ.(/1,0,0/))) THEN
!              write(*,*) 'incell: ',incell
!            END IF

!            prnt = ALL((/neigh,nA,nB/).EQ.(/1,2,4/))

            ! check if this vertex is in the WS cell
!            IF ( incell(rVert(numVert)%r, numNeigh, R, Rmag, tol, prnt) ) THEN
            IF ( incell(rVert(numVert)%r, numNeigh, R, Rmag, tol, .FALSE.) ) THEN
                ! inside the cell
              numVert = numVert + 1
!              write(*,*) "incell = TRUE"
            END IF
          END IF
        END DO
      END DO

!      write(*,*) "neigh: ",neigh," numVert: ",numVert

      !check to make sure none of the vertices correspond to R/2:
      zeroarea = .False.
      DO n = 1, numVert
        IF (ABS(SUM(rVert(n)%r(:)**2)) < (0.5*Rmag(neigh) + tol)) zeroarea = .TRUE.
!       zeroarea = (ABS(SUM(rVert(n)%r(:)**2) - 0.5*Rmag(neigh)) < tol))
      END DO
      IF (zeroarea .OR. numVert == 0) THEN
!        write(*,*) "vert: ",neigh," zeroarea"
        alphtmp(neigh) = 0
        numVect = numVect - 1
        CYCLE
      END IF

      ! Now we have a list of all the vertices for the polygon
      ! defining the facet along the direction R[n].
      ! Last step is to sort the list in terms of a winding angle around
      ! R[n].  To do that, we define rx and ry which are perpendicular
      ! to R[n], normalized, and right-handed: ry = R x rx, so that
      ! rx x ry points along R[n].

      Rx = rvert(1)%r
      rdRn = SUM(rx(:)*R(neigh,:)) / SUM(R(neigh,:)**2)
      Rx(:) = Rx(:) - rdRn*R(neigh,:)
      rdRn = SQRT(SUM(Rx(:)**2))
      Rx = Rx/rdRn
      Ry = cross_product(R(neigh,:), Rx)
      rdRn = SQRT(SUM(Ry(:)**2))
      Ry = Ry/rdRn
!      write (*,*) "numVert now: ",numVert
      DO nvi = 1, numVert - 1
!        write(*,*) "vert: ",nvi
!        write(*,*) SUM(rvert(nvi)%r(:)*Ry(:))," ",SUM(rvert(nvi)%r(:)*Rx(:))
!        write(*,*) ATAN2(SUM(rvert(nvi)%r(:)*Ry(:)), SUM(rvert(nvi)%r(:)*Rx(:)))
        rvert(nvi)%phi = ATAN2(SUM(rvert(nvi)%r(:)*Ry(:)), SUM(rvert(nvi)%r(:)*Rx(:)))
      END DO
!      write(*,*) "before sort"
      CALL sort_vert(numVert - 1, rvert)
!      write(*,*) "after sort"
!      DO nvi = 1, numVert
      alphtmp(neigh) = 0
      DO nvi = 1, numVert - 1
        alphtmp(neigh) = alphtmp(neigh) + &
                         triple_product(rvert(nvi)%r, rvert(MOD(nvi,(numVert-1))+1)%r, R(neigh,:))
      END DO
      alphtmp(neigh) = alphtmp(neigh)*0.25/Rmag(neigh)
      IF (ABS(alphtmp(neigh)) < tol) THEN
        alphtmp(neigh) = 0
        numVect = numVect - 1
      END IF
    END DO 

    ! assign the vertex array with the known number of verticies
    ALLOCATE (vect(numVect,3))
    ALLOCATE (alpha(numVect))

    nvi = 1
    DO n = 1, numNeigh
      IF (alphtmp(n) /= 0 ) THEN
        vect(nvi,:) = nVect(n,:)
        alpha(nvi) = alphtmp(n)
        nvi = nvi + 1
      END IF
    END DO 

!    write(*,*) "numVect: ",numVect
!    DO nvi = 1, numVect
!      write(*,*) vect(nvi,1), " ", vect(nvi,2), " ", vect(nvi,3), " ", alpha(nvi)
!    END DO

  END SUBROUTINE ws_voronoi


  !---------------------------------------------------------------
  ! incell: is a r inside the WS cell defined by the vectors R
  !         rmag = R.R/2
  !---------------------------------------------------------------
  FUNCTION incell(r, numNeigh, rNeigh, rmag, tol, prnt)

    REAL(q2), INTENT(IN), DIMENSION(:) :: r, rmag
    REAL(q2), INTENT(IN), DIMENSION(:,:) :: rNeigh
    LOGICAL incell, prnt
    INTEGER n, numNeigh
    REAL(q2) tol

    incell = .TRUE.
    DO n = 1, numNeigh
      IF(prnt) THEN
         write(*,*) " incell, n: ",n," ", DOT_PRODUCT(r, rNeigh(n,:)), " ", rmag(n)
         write(*,'(A,3F10.6)') "r ",r(:)
         write(*,'(A,3F10.6)') "rNeigh ",rNeigh(n,:)
         write(*,'(A,1F10.6)') "rmag ",rmag(n)
      END IF
      IF (DOT_PRODUCT(r(:), rNeigh(n,:)) > (rmag(n) + tol)) THEN
        incell = .FALSE.
        EXIT
      END IF
    END DO

    RETURN
  END FUNCTION

  !---------------------------------------------------------------
  ! Sort a charge list
  !---------------------------------------------------------------

  SUBROUTINE sort_weight(array_size, weightList)

    INTEGER, INTENT(IN) :: array_size
    TYPE(weight_obj), INTENT(INOUT), DIMENSION(array_size) :: weightList
    INCLUDE "qsort_inline.inc"
  CONTAINS
    SUBROUTINE init()
    END SUBROUTINE init
    LOGICAL &

    FUNCTION less_than(a,b)
      INTEGER, INTENT(IN) :: a,b
      IF ( weightList(a)%rho == weightList(b)%rho ) then
        less_than = a < b
      ELSE
        less_than = weightList(a)%rho > weightList(b)%rho  ! max first
      END IF
    END FUNCTION less_than

    SUBROUTINE swap(a,b)
      INTEGER, INTENT(IN) :: a,b
      TYPE(weight_obj) :: hold
      hold = weightList(a)
      weightList(a) = weightList(b)
      weightList(b) = hold
    END SUBROUTINE swap

  ! circular shift-right by one:
    SUBROUTINE rshift(left,right)
      INTEGER, INTENT(in) :: left, right
      TYPE(weight_obj) :: hold
      hold = weightList(right)
      weightList(left+1:right) = weightList(left:right-1)
      weightList(left) = hold
    END SUBROUTINE rshift
  END SUBROUTINE sort_weight

  !---------------------------------------------------------------
  ! Sort a vertex list
  !---------------------------------------------------------------

  SUBROUTINE sort_vert(array_size, vertList)

    INTEGER, INTENT(IN) :: array_size
    TYPE(rvert_obj), INTENT(INOUT), DIMENSION(array_size) :: vertList
    INCLUDE "qsort_inline.inc"
  CONTAINS
    SUBROUTINE init()
    END SUBROUTINE init
    LOGICAL &

    FUNCTION less_than(a,b)
      INTEGER, INTENT(IN) :: a,b
      IF ( vertList(a)%phi == vertList(b)%phi ) THEN
        less_than = a < b
      ELSE
        less_than = vertList(a)%phi < vertList(b)%phi
      END IF
    END FUNCTION less_than

    SUBROUTINE swap(a,b)
      INTEGER, INTENT(IN) :: a,b
      TYPE(rvert_obj) :: hold
      hold = vertList(a)
      vertList(a) = vertList(b)
      vertList(b) = hold
    END SUBROUTINE swap

  ! circular shift-right by one:
    SUBROUTINE rshift(left,right)
      INTEGER, INTENT(IN) :: left, right
      TYPE(rvert_obj) :: hold
      hold = vertList(right)
      vertList(left+1:right) = vertList(left:right-1)
      vertList(left) = hold
    END SUBROUTINE rshift
  END SUBROUTINE sort_vert

  !---------------------------------------------------------------

  END MODULE
