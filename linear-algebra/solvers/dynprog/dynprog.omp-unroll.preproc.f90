!******************************************************************************
!
!  dynprog.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 50. 
      program dynprog
      integer :: output
      integer, dimension(:,:,:), allocatable :: sumC 
      integer, dimension(:,:), allocatable :: c 
      integer, dimension(:,:), allocatable :: w 
      integer :: i
!     Allocation of Arrays
      allocate(sumC( 50+0, 50+0, 50+0), STAT=I); call check_err(I)
      allocate(c( 50+0, 50+0), STAT=I); call check_err(I)
      allocate(w( 50+0, 50+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(50, c, w)
!     Kernel Execution
      call kernel_dynprog(100, 50, c, w, sumC, output)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(output);  ;
!     Deallocation of Arrays 
      deallocate(sumC)
      deallocate(c)
      deallocate(w)
      contains
        subroutine init_array(length, c, w)
        integer, dimension(length, length) :: w, c
        integer :: i, j
        integer length
        do i = 1, length
          do j = 1, length
            c(j, i) = mod((i-1)*(j-1), 2)
            w(j, i) = (DBLE((i - 1) - (j - 1))) / DBLE(length)
          end do
        end do
        end subroutine
        subroutine print_array(output)
        integer :: output
        write(0, "(i0,1x)", advance='no') output
        write(0, *)
        end subroutine
        subroutine kernel_dynprog(tsteps , length, c, w, sumC, output)
        integer, dimension(length, length) :: w, c
        integer, dimension(length, length, length) :: sumC
        integer :: i, j, iter, k
        integer :: length, tsteps
        integer :: output
      CONTINUE
      !DIR$ scop
        output = 0
        !$omp unroll factor(4)
        do iter = 1, tsteps
          do i = 1, length
            do j = 1, length
              c(j, i) = 0
            end do
          end do
          do i = 1, length - 1
            do j = i + 1, length 
              sumC(i, j, i) = 0
              do k = i + 1, j - 1
                sumC(k, j, i) = sumC(k - 1, j, i) + c(k, i) + c(j, k)
              end do
              c(j, i) = sumC(j - 1, j, i) + w(j, i)
            end do
          end do
          output = output + c(length, 1)
        end do
!DIR$ end scop
        end subroutine
      end program
