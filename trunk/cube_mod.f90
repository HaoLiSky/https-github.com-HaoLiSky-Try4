!-----------------------------------------------------------------------------------!
! Bader charge density analysis program
!  Module for reading and writing charge density data
!-----------------------------------------------------------------------------------!

MODULE cube_mod
  USE kind_mod
  USE matrix_mod
  USE ions_mod
  USE charge_mod
  IMPLICIT NONE

  PRIVATE
  PUBLIC :: read_charge_cube, write_charge_cube

  CONTAINS

!-----------------------------------------------------------------------------------!
! read_charge_cube: Reads the charge density from a file in vasp or Gaussian cube 
!   format, by first reading the header, and then charges
!-----------------------------------------------------------------------------------!

  SUBROUTINE read_charge_cube(ions,chg,chargefile)

    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg
    CHARACTER(LEN=128) :: chargefile

    REAL(q2) :: vol,tmp
    REAL(q2),DIMENSION(3) :: dlat,dcar
    INTEGER :: i,n1,n2,n3,d1,d2,d3

    OPEN(100,FILE=chargefile(1:LEN_TRIM(ADJUSTL(chargefile))), &
    &    STATUS='old',ACTION='read')
    WRITE(*,'(/,1A11,1A20)') 'OPEN ... ',chargefile
    WRITE(*,'(1A27)') 'GAUSSIAN-STYLE INPUT FILE'
    ! Skip the first two lines
    READ(100,'(/)') 
    READ(100,*) ions%nions,chg%org_car
    ALLOCATE(ions%r_car(ions%nions,3),ions%r_dir(ions%nions,3), &
    &        ions%ion_chg(ions%nions))
    DO i=1,3
      READ(100,*) chg%npts(i),chg%lat2car(i,1:3)
    END DO
    ! This should really indicate the units (Bohr/Ang)
    IF(chg%npts(1)<0) chg%npts(1)=(-1)*chg%npts(1)
    chg%i_npts=1.0_q2/REAL(chg%npts,q2)
    ! The -1 is to account for having points at the edge of the cube
    DO i=1,3
!test      ions%lattice(:,i)=chg%lat2car(i,:)*REAL(chg%npts(i)-1,q2)
      ions%lattice(:,i)=chg%lat2car(i,:)*REAL(chg%npts(i),q2)
    END DO
    ! GH: still not sure about this -1.  Should it factor into the
    !     conversion matricies between lat and dir/car, as it is now?
    !     What about the places in which we multiply by npts, or i_npts?
    CALL matrix_transpose(ions%lattice,ions%dir2car)
    CALL matrix_3x3_inverse(ions%dir2car,ions%car2dir)
    DO i=1,3
!test      chg%car2lat(:,i)=ions%car2dir(:,i)*REAL(chg%npts(i)-1,q2)
      chg%car2lat(:,i)=ions%car2dir(:,i)*REAL(chg%npts(i),q2)
    END DO
    vol=matrix_volume(ions%lattice)
    DO i=1,ions%nions
      READ(100,*) tmp,ions%ion_chg(i),ions%r_car(i,:)
!      ions%r_car(i,:)=ions%r_car(i,:)-chg%org_car(:)
      CALL matrix_vector(ions%car2dir,ions%r_car(i,:),ions%r_dir(i,:))
    END DO
    chg%nrho=PRODUCT(chg%npts(:))
    ALLOCATE(chg%rho(chg%npts(1),chg%npts(2),chg%npts(3)))
    READ(100,*) (((chg%rho(n1,n2,n3),  &
    &            n3=1,chg%npts(3)),n2=1,chg%npts(2)),n1=1,chg%npts(1))
! GH: for some reason this is not working; replace with loop
!    chg%rho=chg%rho*vol
    DO n1=1,chg%npts(1)
      DO n2=1,chg%npts(1)
        DO n3=1,chg%npts(1)
          chg%rho(n1,n2,n3)=vol*chg%rho(n1,n2,n3)
        END DO
      END DO
    END DO

    WRITE(*,'(1A12,1I5,1A2,1I4,1A2,1I4)') 'FFT-grid: ',  &
    &         chg%npts(1),'x',chg%npts(2),'x',chg%npts(3)
    WRITE(*,'(2x,A,1A20)') 'CLOSE ... ', chargefile
    CLOSE(100)

    ! Note: this is only for isolated atoms.  For periodic systems, this shift
    ! might not be appropriate

    ! origin of the lattice is at chg(0.5,0.5,0.5)
!    chg%org_lat=(/0.5_q2,0.5_q2,0.5_q2/)
    chg%org_lat=(/1.0_q2,1.0_q2,1.0_q2/)
    CALL matrix_vector(ions%car2dir,chg%org_car,chg%org_dir)

    ! distance between neighboring points
    DO d1=-1,1
      dlat(1)=REAL(d1,q2)
      DO d2=-1,1
        dlat(2)=REAL(d2,q2)
        DO d3=-1,1
          dlat(3)=REAL(d3,q2)
          CALL matrix_vector(chg%lat2car,dlat,dcar)
          chg%lat_dist(d1,d2,d3)=SQRT(SUM(dcar*dcar))
         IF ((d1 == 0).AND.(d2 == 0).AND.(d3 == 0)) THEN
            chg%lat_i_dist(d1,d2,d3)=0.0_q2       
          ELSE
            chg%lat_i_dist(d1,d2,d3)=1.0_q2/chg%lat_dist(d1,d2,d3)
          END IF
        END DO
      END DO
    END DO

  RETURN
  END SUBROUTINE read_charge_cube

!-----------------------------------------------------------------------------------!
! write_charge_cube: Write out a Gaussian cube type file
!-----------------------------------------------------------------------------------!

  SUBROUTINE write_charge_cube(ions,chg,chargefile)

    TYPE(ions_obj) :: ions
    TYPE(charge_obj) :: chg
    CHARACTER(LEN=128) :: chargefile
    
    INTEGER :: i,n1,n2,n3

    OPEN(100,FILE=chargefile(1:LEN_TRIM(ADJUSTL(chargefile))),STATUS='replace')

    WRITE(100,*) 'Gaussian cube file'
    WRITE(100,*) 'Bader charge'
    WRITE(100,'(1I5,3(3X,1F9.6))') ions%nions,chg%org_car
    DO i=1,3
      WRITE(100,'(1I5,3(3X,1F9.6))') chg%npts(i),chg%lat2car(i,:)
    END DO
    DO i=1,ions%nions
    WRITE(100,'(1I5,3X,1F9.6,3(3X,1F9.6))') & 
    &     INT(ions%ion_chg(i)),ions%ion_chg(i),ions%r_car(i,:)
!    &     INT(ions%ion_chg(i)),ions%ion_chg(i),ions%r_car(i,:)+chg%origin
    END DO
    WRITE(100,'(6E13.5)') (((chg%rho(n1,n2,n3), &
    &  n1=1,chg%npts(1)),n2=1,chg%npts(2)),n3=1,chg%npts(3))
    CLOSE(100)
 
  RETURN
  END SUBROUTINE write_charge_cube

END MODULE cube_mod
