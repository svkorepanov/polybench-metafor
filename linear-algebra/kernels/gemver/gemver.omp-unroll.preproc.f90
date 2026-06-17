!******************************************************************************
!
!  gemver.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header.
! Include benchmark-specific header.
! Default data type is double, default size is 4000.
program gemver
   double precision :: alpha
   double precision :: beta
    double precision, dimension(:,:), allocatable :: a
    double precision, dimension(:), allocatable :: u1
    double precision, dimension(:), allocatable :: u2
    double precision, dimension(:), allocatable :: v1
    double precision, dimension(:), allocatable :: v2
    double precision, dimension(:), allocatable :: w
    double precision, dimension(:), allocatable :: x
    double precision, dimension(:), allocatable :: y
    double precision, dimension(:), allocatable :: z
   integer :: n = 500, i
   !     Allocation of Arrays
   allocate(a( n+0, n+0), STAT=I); call check_err(I)
   allocate(u1( n+0), STAT=I); call check_err(I)
   allocate(u2( n+0), STAT=I); call check_err(I)
   allocate(v1( n+0), STAT=I); call check_err(I)
   allocate(v2( n+0), STAT=I); call check_err(I)
   allocate(w( n+0), STAT=I); call check_err(I)
   allocate(x( n+0), STAT=I); call check_err(I)
   allocate(y( n+0), STAT=I); call check_err(I)
   allocate(z( n+0), STAT=I); call check_err(I)
   !     Initialization
   call init_array(n, &
   alpha, beta, a, u1, u2, v1, v2, w, x, y, z)
   !     Kernel Execution
   call kernel_gemver(n, alpha, beta, &
   a, u1, v1, u2, v2, &
   w, x, y, z)
   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
         call print_array(n, w);   ;
   !     Deallocation of Arrays
   deallocate(a)
   deallocate(u1)
   deallocate(u2)
   deallocate(v1)
   deallocate(v2)
   deallocate(w)
   deallocate(x)
   deallocate(y)
   deallocate(z)
   contains
   subroutine init_array(n, alpha, beta, &
   a, u1, u2, v1, v2, w, x, y, z)
      double precision, dimension(n, n) :: a
      double precision, dimension(n) :: u1
      double precision, dimension(n) :: u2
      double precision, dimension(n) :: v1
      double precision, dimension(n) :: v2
      double precision, dimension(n) :: w
      double precision, dimension(n) :: x
      double precision, dimension(n) :: y
      double precision, dimension(n) :: z
      double precision :: alpha, beta
      integer :: n
      integer :: i, j
      alpha = 43532.0d0
      beta = 12313.0d0
      do i = 1, n
         u1(i) = dble(i - 1)
         u2(i) = dble(i / n) / 2.0d0
         v1(i) = dble(i / n) / 4.0d0
         v2(i) = dble(i / n) / 6.0d0
         y(i) = dble(i / n) / 8.0d0
         z(i) = dble(i / n) / 9.0d0
         x(i) = 0.0d0
         w(i) = 0.0d0
         do j = 1, n
            a(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
         end do
      end do
   end subroutine
   subroutine print_array(n, w)
      double precision, dimension(n) :: w
      integer :: n
      integer :: i, j
      do i = 1, n
         write(0, "(f0.2,1x)", advance='no') w(i)
         if (mod(i - 1, 20) == 0) then
            write(0, *)
         end if
      end do
      write(0, *)
   end subroutine
   subroutine kernel_gemver(n, alpha, beta, &
   a, u1, v1, u2, v2, &
   w, x, y, z)
      double precision, dimension(n, n) :: a
      double precision, dimension(n) :: u1
      double precision, dimension(n) :: u2
      double precision, dimension(n) :: v1
      double precision, dimension(n) :: v2
      double precision, dimension(n) :: w
      double precision, dimension(n) :: x
      double precision, dimension(n) :: y
      double precision, dimension(n) :: z
      double precision :: alpha, beta
      integer :: n
      integer :: i, j
            CONTINUE
      !DIR$ scop
      !$omp unroll factor(4)
      do i = 1, n
         do j = 1, n
            a(j, i) = a(j, i) + (u1(i) * v1(j)) + (u2(i) * v2(j))
         end do
      end do
      do i = 1, n
         do j = 1, n
            x(i) = x(i) + (beta * a(i, j) * y(j))
         end do
      end do
      do i = 1, n
         x(i) = x(i) + z(i)
      end do
      do i = 1, n
         do j = 1, n
            w(i) = w(i) + (alpha * a(j, i) * x(j))
         end do
      end do
      !DIR$ end scop
   end subroutine
end program
