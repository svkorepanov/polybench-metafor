!******************************************************************************
!
!  correlation.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program correlation
      double precision :: FLOAT_N
      double precision, dimension(:,:), allocatable :: dat 
      double precision, dimension(:,:), allocatable :: symmat 
      double precision, dimension(:), allocatable :: stddev 
      double precision, dimension(:), allocatable :: mean 
      integer :: i
!     Allocation of Arrays
      allocate(dat( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(symmat( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(stddev( 500+0), STAT=I); call check_err(I)
      allocate(mean( 500+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(500, 500, FLOAT_N, dat)
!     Kernel Execution
      call kernel_correlation(500, 500, FLOAT_N, dat, symmat,  &
                                  mean, stddev)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(500, symmat);  ;
!     Deallocation of Arrays 
      deallocate(dat)
      deallocate(symmat)
      deallocate(stddev)
      deallocate(mean)
      contains
        subroutine init_array(m, n, float_n, dat)
        double precision, dimension(500, 500) :: dat
        double precision :: float_n
        integer :: m, n
        integer :: i, j
        float_n = 1.2D0
        do i = 1, m 
          do j = 1, n
            dat(j, i) = (DBLE(i - 1) * DBLE(j - 1)) / DBLE(m)
          end do
        end do
        end subroutine
        subroutine print_array(m, symmat)
        double precision, dimension(500, 500) :: symmat
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
        subroutine kernel_correlation(m, n, float_n, dat, symmat, &
                                           mean, stddev)
        double precision, dimension(n,m) :: dat
        double precision, dimension(m,m) :: symmat
        double precision, dimension(m) :: stddev 
        double precision, dimension(m) :: mean
        double precision :: float_n, EPS
        integer :: m, n
        integer :: i, j, j1, j2
        EPS = 0.1D0
      CONTINUE
      !DIR$ scop
!       Determine mean of column vectors of input data matrix
        !$omp unroll factor(4)
        do j = 1, m
          mean(j) = 0.0D0
          do i = 1, n
            mean(j) = mean(j) + dat(j, i)
          end do
          mean(j) = mean(j) / float_n
        end do
!       Determine standard deviations of column vectors of data matrix.
        do j = 1, m
          stddev(j) = 0.0D0
          do i = 1, n
            stddev(j) = stddev(j) + (dat(j, i) - mean(j)) * (dat(j, i) - &
                        mean(j))
          end do
          stddev(j) = stddev(j) / float_n
          stddev(j) = sqrt(stddev(j))
          if (stddev(j) <= EPS) then
            stddev(j) = 1.0D0
          endif
        end do
!       Center and reduce the column vectors.
        do i = 1, n
          do j = 1, m
            dat(j, i) = dat(j, i) - mean(j)
            dat(j, i) = dat(j, i) / (sqrt(float_n) * stddev(j))
          end do
        end do
!       Calculate the m * m correlation matrix.
        do j1 = 1, m - 1 
          symmat(j1, j1) = 1.0D0
          do j2 = j1 + 1, m 
            symmat(j2, j1) = 0.0D0
            do i = 1, n
             symmat(j2, j1) = symmat(j2, j1) + (dat(j1, i) * dat(j2, i))
            end do
            symmat(j1, j2) = symmat(j2, j1)
          end do
        end do
        symmat(m, m) = 1.0D0
!DIR$ end scop
        end subroutine
      end program
