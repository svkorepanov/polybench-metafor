!******************************************************************************
!
!  covariance.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header.
! Include benchmark-specific header.
! Default data type is double, default size is 4000.
program covariance
   double precision :: float_n
    double precision, dimension(:,:), allocatable :: dat
    double precision, dimension(:,:), allocatable :: symmat
    double precision, dimension(:), allocatable :: mean
   integer :: n = 500, m = 500, i
   !     Allocation of Arrays
   allocate(dat( n+0, m+0), STAT=I); call check_err(I)
   allocate(symmat( m+0, m+0), STAT=I); call check_err(I)
   allocate(mean( m+0), STAT=I); call check_err(I)
   !     Initialization
   call init_array(m, n, float_n, dat)
   !     Kernel Execution
   call kernel_covariance(m, n, float_n, dat, symmat, mean)
   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
         call print_array(m, symmat);   ;
   !     Deallocation of Arrays
   deallocate(dat)
   deallocate(symmat)
   deallocate(mean)
   contains
   subroutine init_array(m, n, float_n, dat)
      double precision, dimension(n, m) :: dat
      double precision :: float_n
      integer :: m, n
      integer :: i, j
      float_n = 1.2d0
      do i = 1, m
         do j = 1, n
            dat(j, i) = (dble((i - 1) * (j - 1))) / dble(m)
         end do
      end do
   end subroutine
   subroutine print_array(m, symmat)
      double precision, dimension(m, m) :: symmat
      integer :: m
      integer :: i, j
      do i = 1, m
         do j = 1, m
            write(0, "(f0.2,1x)", advance='no') symmat(j, i)
            if (mod(((i - 1) * m) + j - 1, 20) == 0) then
               write(0, *)
            end if
         end do
      end do
      write(0, *)
   end subroutine
   subroutine kernel_covariance(m, n, float_n, dat, symmat, mean)
      double precision, dimension(m, m) :: symmat
      double precision, dimension(n, m) :: dat
      double precision, dimension(m) :: mean
      double precision :: float_n
      integer :: m, n
      integer :: i, j, j1, j2
            CONTINUE
      !DIR$ scop
      !       Determine mean of column vectors of input data matrix
      !$omp tile sizes(32,32)
      do j = 1, m
         mean(j) = 0.0d0
         do i = 1, n
            mean(j) = mean(j) + dat(j, i)
         end do
         mean(j) = mean(j) / float_n
      end do
      !       Center the column vectors.
      do i = 1, n
         do j = 1, m
            dat(j, i) = dat(j, i) - mean(j)
         end do
      end do
      !       Calculate the m * m covariance matrix.
      do j1 = 1, m
         do j2 = j1, m
            symmat(j2, j1) = 0.0d0
            do i = 1, n
               symmat(j2, j1) = symmat(j2, j1) + (dat(j1, i) * dat(j2, i))
            end do
            symmat(j1, j2) = symmat(j2, j1)
         end do
      end do
      !DIR$ end scop
   end subroutine
end program
