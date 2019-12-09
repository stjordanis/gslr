module GSLR
  class OLS < Model
    attr_reader :covariance, :chi2

    def fit(x, y, weight: nil)
      # set data
      xc, s1, s2 = set_matrix(x, intercept: @fit_intercept)
      yc = set_vector(y)

      # allocate solution
      c = FFI.gsl_vector_alloc(s2)
      cov = FFI.gsl_matrix_alloc(s2, s2)
      chisq = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE)
      work = FFI.gsl_multifit_linear_alloc(s1, s2)

      # fit
      if weight
        wc = set_vector(weight)
        FFI.gsl_multifit_wlinear(xc, wc, yc, c, cov, chisq, work)
      else
        FFI.gsl_multifit_linear(xc, yc, c, cov, chisq, work)
      end

      # read solution
      c_ptr = FFI.gsl_vector_ptr(c, 0)
      @coefficients = c_ptr[0, s2 * Fiddle::SIZEOF_DOUBLE].unpack("d*")
      @intercept = @fit_intercept ? @coefficients.shift : 0.0
      @covariance = read_matrix(cov, s2)
      @chi2 = chisq[0, Fiddle::SIZEOF_DOUBLE].unpack1("d")

      nil
    ensure
      FFI.gsl_matrix_free(xc) if xc
      FFI.gsl_vector_free(yc) if yc
      FFI.gsl_vector_free(wc) if wc
      FFI.gsl_vector_free(c) if c
      FFI.gsl_matrix_free(cov) if cov
      FFI.gsl_multifit_linear_free(work) if work
    end

    private

    def read_matrix(cov, s2)
      ptr = FFI.gsl_matrix_ptr(cov, 0, 0)
      row_size = s2 * Fiddle::SIZEOF_DOUBLE
      s2.times.map do |i|
        ptr[i * row_size, row_size].unpack("d*")
      end
    end
  end
end
