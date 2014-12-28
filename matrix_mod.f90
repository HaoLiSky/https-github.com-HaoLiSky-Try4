!-----------------------------------------------------------------------------------!
! Bader charge density analysis program
!  Module containing matrix functions
!-----------------------------------------------------------------------------------!
MODULE matrix_mod
  USE kind_mod
  IMPLICIT NONE

  PRIVATE
  PUBLIC :: matrix_mult,matrix_vector,vector_matrix
  PUBLIC :: matrix_transpose,matrix_volume
  PUBLIC :: matrix_3x3_inverse
  PUBLIC :: scalar_matrix,matrix_addition,matrix_substraction
  PUBLIC :: scalar_vector,vector_addition,vector_substraction
  PUBLIC :: cross_product,det
  CONTAINS

!-----------------------------------------------------------------------------------!
! matrix_mult:  Multiply the matricies A and B and return the product C
!-----------------------------------------------------------------------------------!

  SUBROUTINE matrix_mult(A,B,C)

    REAL(q2),INTENT(IN),DIMENSION(:,:) :: A,B
    REAL(q2),INTENT(OUT),DIMENSION(:,:) :: C
    INTEGER :: m,n,j,k

    m=SIZE(A,2)
    n=SIZE(B,2)

! comment this check to optimize
!    IF(m .ne. SIZE(B,1)) THEN
!      WRITE(*,*) 'ERROR: matrix multiplication dimensions do not match'
!      STOP
!    END IF

    DO j=1,n
      C(:,j)=0._q2
      DO k=1,m
        C(:,j)=C(:,j)+B(k,j)*A(:,k)
      END DO
    END DO

  RETURN
  END SUBROUTINE matrix_mult

!-----------------------------------------------------------------------------------!
! matrix_vector:  Multiply the matrix M with the vector V and return the product Vp
!-----------------------------------------------------------------------------------!

  SUBROUTINE matrix_vector(M,V,Vp)

    REAL(q2),INTENT(IN),DIMENSION(:,:) :: M
    REAL(q2),INTENT(IN),DIMENSION(:) :: V
    REAL(q2),INTENT(OUT),DIMENSION(:) :: Vp

    INTEGER :: i,n

    n=SIZE(V)

!    IF(n .ne. SIZE(M,2)) THEN
!      WRITE(*,*) 'ERROR: matrix-vector multiplication dimensions do not match'
!      STOP
!    END IF

    Vp=0._q2
    DO i=1,n
      Vp=Vp+V(i)*M(:,i)
    END DO

  RETURN
  END SUBROUTINE matrix_vector

!-----------------------------------------------------------------------------------!
! vector_matrix:  Multiply the vector V with the matrix M and return the product Vp
!-----------------------------------------------------------------------------------!

  SUBROUTINE vector_matrix(V,M,Vp)

    REAL(q2),INTENT(IN),DIMENSION(:) :: V
    REAL(q2),INTENT(IN),DIMENSION(:,:) :: M
    REAL(q2),INTENT(OUT),DIMENSION(:) :: Vp

    INTEGER :: i,n

    n=SIZE(V)

!    IF(n .ne. SIZE(M,1)) THEN
!      WRITE(*,*) 'ERROR: matrix-vector multiplication dimensions do not match'
!      STOP
!    END IF

    Vp=0._q2
    DO i=1,n
      Vp=Vp+V(i)*M(i,:)
    END DO

  RETURN
  END SUBROUTINE vector_matrix

!-----------------------------------------------------------------------------------!
! matrix_transpose:  Set matrix B to be the transpose of A
!-----------------------------------------------------------------------------------!

  SUBROUTINE matrix_transpose(A,B)

    REAL(q2),INTENT(IN),DIMENSION(:,:) :: A
    REAL(q2),INTENT(INOUT),DIMENSION(:,:) :: B

    INTEGER :: i,j,n,m

    n=SIZE(A,1)
    m=SIZE(A,2)

    DO i=1,n
      DO j=1,m
        B(j,i)=A(i,j)
      END DO
    END DO

  RETURN
  END SUBROUTINE matrix_transpose

!-----------------------------------------------------------------------------------!
! matrix_3x3_inverse:  Set matrix B to be the inverse of A
!-----------------------------------------------------------------------------------!

  SUBROUTINE matrix_3x3_inverse(A,B)

    REAL(q2),INTENT(IN),DIMENSION(3,3) :: A
    REAL(q2),INTENT(OUT),DIMENSION(3,3) :: B
    REAL(q2) :: det
    INTEGER :: i,j,it,jt

    det=0
    DO i=1,3
      it=i-1
      DO j=1,3
        jt=j-1
        B(j,i) = & 
        &      A(mod(it+1,3)+1,mod(jt+1,3)+1)*A(mod(it+2,3)+1,mod(jt+2,3)+1)  &
        &     -A(mod(it+1,3)+1,mod(jt+2,3)+1)*A(mod(it+2,3)+1,mod(jt+1,3)+1)
      END DO
      det=det+A(i,1)*B(1,i)
    END DO

    DO i=1,3
      DO j=1,3
        B(i,j)=B(i,j)/det
      END DO
    END DO

  RETURN
  END SUBROUTINE matrix_3x3_inverse

!-----------------------------------------------------------------------------------!
! matrix_volume: Function returning the triple product of the lattice vectors.
!-----------------------------------------------------------------------------------!
    
  FUNCTION matrix_volume(h)

    REAL(q2),INTENT(IN),DIMENSION(3,3) :: h
    REAL(q2) :: matrix_volume
    
    matrix_volume = h(1,1)*(h(2,2)*h(3,3)-h(2,3)*h(3,2))  &
    &              -h(1,2)*(h(2,1)*h(3,3)-h(3,1)*h(2,3))  &
    &              +h(1,3)*(h(2,1)*h(3,2)-h(3,1)*h(2,2))

    matrix_volume = abs(matrix_volume)

  RETURN
  END FUNCTION matrix_volume

!-----------------------------------------------------------------------------------!
! scalar_matrix: multiply the matrix with a scalar and return the matrix
!-----------------------------------------------------------------------------------!
  SUBROUTINE scalar_matrix(S,M,MO)

    REAL(q2),INTENT(IN),DIMENSION(:,:) :: M
    REAL(q2),INTENT(OUT),DIMENSION(:,:) :: MO
    REAL(q2),INTENT(IN) :: S
    INTEGER :: i1,i2,n1,n2
    i1=SIZE(M,1)
    i2=SIZE(M,2)
    
    DO n1=1,i1
      DO n2=1,i2
        MO(n1,n2)=S*M(n1,n2)
      END DO
    END DO
    RETURN
  END SUBROUTINE

!-----------------------------------------------------------------------------------!
! scalar_vector: multiply the vector with a scalar and return the vector
!-----------------------------------------------------------------------------------!
  SUBROUTINE scalar_vector(S,V,VO)

    REAL(q2),INTENT(IN),DIMENSION(:) :: V
    REAL(q2),INTENT(OUT),DIMENSION(:) :: VO
    REAL(q2),INTENT(IN) :: S
    INTEGER :: i1,n1
    i1=SIZE(V,1)

    DO n1=1,i1
      VO(n1)=S*V(n1)
    END DO
    RETURN
  END SUBROUTINE

!-----------------------------------------------------------------------------------!
! matrix_addition: return C = A + B
!-----------------------------------------------------------------------------------!
  SUBROUTINE matrix_addition(A,B,C)
    REAL(q2),INTENT(IN),DIMENSION(:,:) :: A,B
    REAL(q2),INTENT(OUT),DIMENSION(:,:) :: C
    INTEGER :: i1,i2,n1,n2
    i1=SIZE(A,1)
    i2=SIZE(A,2)
    DO n1=1,i1
      DO n2=1,i2
        C(n1,n2)=A(n1,n2)+B(n1,n2)
      END DO
    END DO
    RETURN
  END SUBROUTINE

!-----------------------------------------------------------------------------------!
! matrix_substraction: return C = A - B$
!-----------------------------------------------------------------------------------!
  SUBROUTINE matrix_substraction(A,B,C)
    REAL(q2),INTENT(IN),DIMENSION(:,:) :: A,B
    REAL(q2),INTENT(OUT),DIMENSION(:,:) :: C
    INTEGER :: i1,i2,n1,n2
    i1=SIZE(A,1)
    i2=SIZE(A,2)
    DO n1=1,i1
      DO n2=1,i2
        C(n1,n2)=A(n1,n2)-B(n1,n2)
      END DO
    END DO
    RETURN
  END SUBROUTINE

!-----------------------------------------------------------------------------------!
! vector_addition: return C = A + B$
!-----------------------------------------------------------------------------------!
  SUBROUTINE vector_addition(A,B,C)
    REAL(q2),INTENT(IN),DIMENSION(:) :: A,B
    REAL(q2),INTENT(OUT),DIMENSION(:) :: C
    INTEGER :: i1,n1
    i1=SIZE(A,1)
    DO n1=1,i1
      C(n1)=A(n1)+B(n1)
    END DO
    RETURN
  END SUBROUTINE

!-----------------------------------------------------------------------------------!
! vector_substraction: return C = A - B$
!-----------------------------------------------------------------------------------!
  SUBROUTINE vector_substraction(A,B,C)
    REAL(q2),INTENT(IN),DIMENSION(:) :: A,B
    REAL(q2),INTENT(OUT),DIMENSION(:) :: C
    INTEGER :: i1,n1
    i1=SIZE(A,1)
    DO n1=1,i1
      C(n1)=A(n1)-B(n1)
    END DO
    RETURN
  END SUBROUTINE

!-----------------------------------------------------------------------------------!
! cross_product: calculate the cross product of two vectors
!-----------------------------------------------------------------------------------!
  SUBROUTINE cross_product(A,B,C)
    REAL(q2),INTENT(IN),DIMENSION(3) :: A,B
    REAL(q2),INTENT(OUT),DIMENSION(3) :: C
    C(1)=A(2)*B(3)-A(3)*B(2)
    C(2)=A(3)*B(1)-A(1)*B(3)
    C(3)=A(1)*B(2)-A(2)*B(1)
    RETURN
  END SUBROUTINE

!-----------------------------------------------------------------------------------!
! det: find the determinant of a 3x3 matrix 
!-----------------------------------------------------------------------------------!
  SUBROUTINE det(A,B)
    REAL(q2),INTENT(IN),DIMENSION(3,3) :: A
    REAL(q2),INTENT(OUT) :: B
    B = A(1,1)*A(2,2)*A(3,3) &
       -A(1,1)*A(2,3)*A(3,2) &
       -A(1,2)*A(2,1)*A(3,3) &
       +A(1,2)*A(2,3)*A(3,1) &
       +A(1,3)*A(2,1)*A(3,2) &
       -A(1,3)*A(2,2)*A(3,1)
    RETURN
    END SUBROUTINE

!-----------------------------------------------------------------------------------!

END MODULE matrix_mod

