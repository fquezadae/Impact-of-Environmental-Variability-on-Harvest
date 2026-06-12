// =============================================================================
// paper1/stan/t4b_state_space_omega.stan
//
// T4b paso 6(c) -- 3 stocks + correlacion cruzada de ruido de proceso Omega.
// Extiende t4b_state_space_ind.stan (Omega = I implicito) con una matriz de
// correlacion estimada via factor de Cholesky.
//
// Cambios respecto a t4b_state_space_ind.stan:
//   (+) cholesky_factor_corr[S] L_Omega       // nuevo parametro
//   (+) L_Omega ~ lkj_corr_cholesky(4)        // prior mas apretado que (2)
//       del T4 v1 -- tira hacia independencia pero permite correlacion si los
//       datos lo exigen. eta=4 reduce la masa en |rho| > 0.6.
//   (~) logB[t] ~ multi_normal_cholesky(logB_mean_t,
//                                       diag_pre_multiply(sigma_proc, L_Omega))
//       Reemplaza la dinamica univariada por stock (Omega = I) con una
//       dinamica multivariada que comparte ruido correlacionado.
//   (+) Omega = L_Omega * L_Omega' reportado en generated quantities.
//
// Representacion del estado latente:
//   Ahora logB es array[T] vector[S] (no matrix[T,S]) para que el argumento
//   de multi_normal_cholesky sea un vector[S] natural. B_smooth se expone
//   como matrix[T,S] en generated quantities para que el pipeline de PPC
//   previo siga funcionando.
//
// Observacion: con sigma_proc[3] (jurel) ~ 1.2 mucho mayor que sigma_proc[1,2]
// (~0.3), las covariaciones que involucran jurel van a tener bandas muy
// amplias. Es esperable que Omega[1,3] y Omega[2,3] queden cercanas a cero
// con incertidumbre alta. Omega[1,2] (anch-sard) es la mas informativa.
// =============================================================================

functions {
  real schaefer_step_log(real logB, real logK, real r_t, real C) {
    real B   = exp(logB);
    real K   = exp(logK);
    real g   = r_t * B * (1.0 - B / K);
    real B1  = B + g - C;
    real floor_ = 0.01 * K;
    return log(fmax(floor_, B1));
  }
}

data {
  int<lower=1> S;
  int<lower=1> T;
  int<lower=1> N_obs_anch;
  int<lower=1> N_obs_sard;
  int<lower=1> N_obs_jur_unc;
  int<lower=0> N_obs_jur_cen;

  array[N_obs_anch]    int<lower=1, upper=T> t_anch;
  array[N_obs_sard]    int<lower=1, upper=T> t_sard;
  array[N_obs_jur_unc] int<lower=1, upper=T> t_jur_unc;
  array[N_obs_jur_cen] int<lower=1, upper=T> t_jur_cen;

  vector<lower=0>[N_obs_anch]    B_obs_anch;
  vector<lower=0>[N_obs_sard]    B_obs_sard;
  vector<lower=0>[N_obs_jur_unc] B_obs_jur;
  real<lower=0> B_censor_limit_jurel;

  matrix<lower=0>[T, S] C;

  vector[S] log_r_prior_mean;
  vector<lower=0>[S] log_r_prior_sd;
  vector[S] log_K_prior_mean;
  vector<lower=0>[S] log_K_prior_sd;
  vector[S] log_B0_prior_mean;
  vector<lower=0>[S] log_B0_prior_sd;

  vector<lower=0>[S] sigma_obs_prior_mean;
  vector<lower=0>[S] sigma_obs_prior_sd;

  vector[S] sigma_proc_prior_logmean;
  vector<lower=0>[S] sigma_proc_prior_logsd;
}

transformed data {
  int IDX_ANCH = 1;
  int IDX_SARD = 2;
  int IDX_JUR  = 3;

  vector[N_obs_anch]    log_B_obs_anch = log(B_obs_anch);
  vector[N_obs_sard]    log_B_obs_sard = log(B_obs_sard);
  vector[N_obs_jur_unc] log_B_obs_jur  = log(B_obs_jur);
  real log_B_censor_limit_jurel        = log(B_censor_limit_jurel);

  int N_obs_total = N_obs_anch + N_obs_sard + N_obs_jur_unc + N_obs_jur_cen;
}

parameters {
  vector[S] z_log_r;
  vector[S] z_log_K;
  vector[S] z_log_B0;

  vector<lower=0>[S] sigma_proc;
  vector<lower=0>[S] sigma_obs;

  // NUEVO: factor Cholesky de la correlacion de ruido de proceso
  cholesky_factor_corr[S] L_Omega;

  // Estado latente como array[T] vector[S] (natural para multi_normal)
  array[T] vector[S] logB;
}

transformed parameters {
  vector[S] log_r  = log_r_prior_mean  + z_log_r  .* log_r_prior_sd;
  vector[S] log_K  = log_K_prior_mean  + z_log_K  .* log_K_prior_sd;
  vector[S] log_B0 = log_B0_prior_mean + z_log_B0 .* log_B0_prior_sd;
  vector<lower=0>[S] r_ = exp(log_r);
}

model {
  // Priors estructurales
  z_log_r  ~ std_normal();
  z_log_K  ~ std_normal();
  z_log_B0 ~ std_normal();

  // Priors ruido
  for (s in 1:S) {
    sigma_proc[s] ~ lognormal(sigma_proc_prior_logmean[s], sigma_proc_prior_logsd[s]);
    sigma_obs[s]  ~ normal(sigma_obs_prior_mean[s], sigma_obs_prior_sd[s]);
  }

  // Prior LKJ apretado hacia independencia (eta=4 vs eta=2 del T4 v1)
  L_Omega ~ lkj_corr_cholesky(4);

  // Dinamica multivariada (CENTERED). La factorizacion de Cholesky del
  // proceso covariance es diag(sigma_proc) * L_Omega (lower triangular).
  {
    matrix[S, S] L_proc = diag_pre_multiply(sigma_proc, L_Omega);

    // Ano 1: sin correlacion cruzada (condicion inicial independiente por stock)
    for (s in 1:S) {
      logB[1][s] ~ normal(log_B0[s], sigma_proc[s]);
    }

    // Anos 2..T: innovaciones correlacionadas
    for (t in 2:T) {
      vector[S] logB_mean_t;
      for (s in 1:S) {
        logB_mean_t[s] = schaefer_step_log(logB[t - 1][s], log_K[s], r_[s], C[t - 1, s]);
      }
      logB[t] ~ multi_normal_cholesky(logB_mean_t, L_proc);
    }
  }

  // Likelihood (indexacion logB[t][s])
  for (n in 1:N_obs_anch) {
    log_B_obs_anch[n] ~ normal(logB[t_anch[n]][IDX_ANCH], sigma_obs[IDX_ANCH]);
  }
  for (n in 1:N_obs_sard) {
    log_B_obs_sard[n] ~ normal(logB[t_sard[n]][IDX_SARD], sigma_obs[IDX_SARD]);
  }
  for (n in 1:N_obs_jur_unc) {
    log_B_obs_jur[n] ~ normal(logB[t_jur_unc[n]][IDX_JUR], sigma_obs[IDX_JUR]);
  }
  for (n in 1:N_obs_jur_cen) {
    target += normal_lcdf(
      log_B_censor_limit_jurel |
      logB[t_jur_cen[n]][IDX_JUR], sigma_obs[IDX_JUR]
    );
  }
}

generated quantities {
  vector<lower=0>[S] r_nat  = r_;
  vector<lower=0>[S] K_nat  = exp(log_K);
  vector<lower=0>[S] B0_nat = exp(log_B0);

  // Correlacion de proceso en escala legible
  corr_matrix[S] Omega = multiply_lower_tri_self_transpose(L_Omega);

  // B_smooth como matrix[T,S] para compatibilidad con pipeline PPC
  matrix<lower=0>[T, S] B_smooth;
  for (t in 1:T) for (s in 1:S) B_smooth[t, s] = exp(logB[t][s]);

  vector[N_obs_total] log_lik;
  {
    int pos = 1;
    for (n in 1:N_obs_anch) {
      log_lik[pos] = normal_lpdf(log_B_obs_anch[n] |
                                 logB[t_anch[n]][IDX_ANCH], sigma_obs[IDX_ANCH]);
      pos += 1;
    }
    for (n in 1:N_obs_sard) {
      log_lik[pos] = normal_lpdf(log_B_obs_sard[n] |
                                 logB[t_sard[n]][IDX_SARD], sigma_obs[IDX_SARD]);
      pos += 1;
    }
    for (n in 1:N_obs_jur_unc) {
      log_lik[pos] = normal_lpdf(log_B_obs_jur[n] |
                                 logB[t_jur_unc[n]][IDX_JUR], sigma_obs[IDX_JUR]);
      pos += 1;
    }
    for (n in 1:N_obs_jur_cen) {
      log_lik[pos] = normal_lcdf(log_B_censor_limit_jurel |
                                 logB[t_jur_cen[n]][IDX_JUR], sigma_obs[IDX_JUR]);
      pos += 1;
    }
  }

  vector<lower=0>[N_obs_anch]    B_rep_anch;
  vector<lower=0>[N_obs_sard]    B_rep_sard;
  vector<lower=0>[N_obs_jur_unc] B_rep_jur;
  for (n in 1:N_obs_anch)
    B_rep_anch[n] = exp(normal_rng(logB[t_anch[n]][IDX_ANCH], sigma_obs[IDX_ANCH]));
  for (n in 1:N_obs_sard)
    B_rep_sard[n] = exp(normal_rng(logB[t_sard[n]][IDX_SARD], sigma_obs[IDX_SARD]));
  for (n in 1:N_obs_jur_unc)
    B_rep_jur[n]  = exp(normal_rng(logB[t_jur_unc[n]][IDX_JUR], sigma_obs[IDX_JUR]));
}
