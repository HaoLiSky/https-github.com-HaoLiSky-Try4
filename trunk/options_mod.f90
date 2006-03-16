  MODULE options_mod
    USE kind_mod , ONLY : q2
    IMPLICIT NONE

    TYPE :: l_list_obj
      LOGICAL :: lp_all,lp_atom,lp_none,lo_cube,lo_chgcar,lc_all,lc_bader,lc_voronoi,          &
     &           lc_dipole,lc_ldos,li_cube,li_chgcar,lr_badertol
    END TYPE l_list_obj

    TYPE :: options_obj
      TYPE(l_list_obj) llist 
      CHARACTER(LEN=120) :: chargefile
      REAL(q2) :: badertol
    END TYPE options_obj

    PRIVATE
    PUBLIC :: get_options,l_list_obj,options_obj

    CONTAINS
!----------------------------------------------------------------------------------------------!

    SUBROUTINE get_options(opts)

      TYPE(options_obj) :: opts
      LOGICAL :: ertil, inl
      INTEGER :: n,iargc,i,ip,m,it,ini
      REAL(q2) :: inr,temp
      CHARACTER(LEN=120) :: p
      CHARACTER(LEN=30) :: inc

! Default values
      opts%llist=l_list_obj(.FALSE.,.FALSE.,.FALSE.,.FALSE.,.FALSE.,.FALSE.,.FALSE.,         &
     &                 .FALSE.,.FALSE.,.FALSE.,.FALSE.,.FALSE.,.FALSE.)
      opts%badertol=1.0e-4_q2

      n=IARGC()
      IF (MOD(n-1,2) /= 0) THEN
        WRITE(*,'(A)') ' Not the right number of input parameters !!!'
        STOP
      END IF
      IF (n >= 1) THEN
        CALL GETARG(1,opts%chargefile)               ! Get the charge density filename
! Make sure that that charge density file exists here
        i=LEN_TRIM(ADJUSTL(opts%chargefile))
        INQUIRE(FILE=opts%chargefile(1:i),EXIST=ertil)
        IF (.NOT. ertil) THEN
          WRITE(*,'(2X,A,A)') opts%chargefile(1:i),' DOES NOT EXIST IN THIS DIRECTORY'
          STOP
        END IF 
        DO m=2,n-1,2
          CALL GETARG(m,p)                      ! Check for flags
          p=ADJUSTL(p)
          ip=LEN_TRIM(p)
          i=INDEX(p,'-')
          IF (i /= 1) THEN
            WRITE(*,'(A,A,A)') ' Option "',p(1:ip),'" is not valid !!!'
            WRITE(*,*) ' '
            WRITE(*,'(A)') ' Correct usage is: '
            WRITE(*,'(A)') ' <program name> <charge density file> -<option flag 1> <option 1> etc.'
            STOP
          END IF

          IF (p(1:ip) == '-v') THEN                                   ! Verbose
          ELSEIF (p(1:ip) == '-p') THEN                               ! Print options
            CALL GETARG(m+1,inc)
            inc=ADJUSTL(inc)
            it=LEN_TRIM(inc)
            IF (inc(1:it) == 'ALL' .OR. inc(1:it) == 'all') THEN
              opts%llist%lp_all=.TRUE.
            ELSEIF (inc(1:it) == 'ATOM' .OR. inc(1:it) == 'atom') THEN
              opts%llist%lp_atom=.TRUE.
            ELSEIF (inc(1:it) == 'NONE' .OR. inc(1:it) == 'none') THEN
              opts%llist%lp_none=.TRUE.
            ELSE
              WRITE(*,'(A,A,A)') ' Unknown option "',inc(1:it),'"'
              STOP
            END IF
          ELSEIF (p(1:ip) == '-o') THEN                               ! Output file type
            CALL GETARG(m+1,inc)
            inc=ADJUSTL(inc)
            it=LEN_TRIM(inc)
            IF (inc(1:it) == 'CUBE' .OR. inc(1:it) == 'cube') THEN
              opts%llist%lo_cube=.TRUE.
            ELSEIF (inc(1:it) == 'CHGCAR' .OR. inc(1:it) == 'chgcar') THEN
              opts%llist%lo_chgcar=.TRUE.
            ELSE
              WRITE(*,'(A,A,A)') ' Unknown option "',inc(1:it),'"'
              STOP
            END IF  
          ELSEIF (p(1:ip) == '-c') THEN                               ! Calculate
            CALL GETARG(m+1,inc)
            inc=ADJUSTL(inc)
            it=LEN_TRIM(inc)
            IF (inc(1:it) == 'ALL' .OR. inc(1:it) == 'all') THEN
              opts%llist%lc_all=.TRUE.
              opts%llist%lc_bader=.TRUE.
              opts%llist%lc_voronoi=.TRUE.
              opts%llist%lc_dipole=.TRUE.
              opts%llist%lc_ldos=.TRUE.
            ELSEIF (inc(1:it) == 'BADER' .OR. inc(1:it) == 'bader') THEN
              opts%llist%lc_bader=.TRUE.
            ELSEIF (inc(1:it) == 'VORONOI' .OR. inc(1:it) == 'voronoi') THEN
              opts%llist%lc_voronoi=.TRUE.
            ELSEIF (inc(1:it) == 'DIPOLE' .OR. inc(1:it) == 'dipole') THEN
              opts%llist%lc_dipole=.TRUE.
            ELSEIF (inc(1:it) == 'LDOS' .OR. inc(1:it) == 'lDOs') THEN
              opts%llist%lc_ldos=.TRUE.
            ELSE
              WRITE(*,'(A,A,A)') ' Unknown option "',inc(1:it),'"'
              STOP
            END IF
          ELSEIF (p(1:ip) == '-i') THEN                               ! Output file type
            CALL GETARG(m+1,inc)
            inc=ADJUSTL(inc)
            it=LEN_TRIM(inc)
            IF (inc(1:it) == 'CUBE' .OR. inc(1:it) == 'cube') THEN
              opts%llist%li_cube=.TRUE.
            ELSEIF (inc(1:it) == 'CHGCAR' .OR. inc(1:it) == 'chgcar') THEN
              opts%llist%li_chgcar=.TRUE.
            ELSE
              WRITE(*,'(A,A,A)') ' Unknown option "',inc(1:it),'"'
              STOP
            END IF
          ELSEIF (p(1:ip) == '-t') THEN                               ! Bader tolerance
            CALL GETARG(m+1,inr)
!            temp=REAL(inr,q2)
            write(*,*) inr
!            opts%badertol=inr
          ELSE
            WRITE(*,'(A,A,A)') ' Unknown option flag "',p(1:ip),'"'
            STOP
          END IF 

        END DO
      END IF
 
    RETURN
    END SUBROUTINE get_options

!----------------------------------------------------------------------------------------------!

  END module options_mod
