// =============================================================================
// paper1/stan/t4b_state_space_full_stockenv.stan
//
// Variante del t4b_state_space_full.stan que admite covariados ambientales
// STOCK-ESPECIFICOS. Usado para Apendice E del paper 1 (robustez espacial de
// la no-identificacion de jurel).
//
// Diferencia unica respecto a t4b_state_space_full.stan:
//   - SST_c y logCHL_c son matrix[T, S] en vez de vector[T].
//   - La dinamica usa SST_c[t-1, s] y logCHL_c[t-1, s].
//
// Esto permite, por ejemplo:
//   - Anch y sard ven SIEMPRE la serie centro_sur_eez (D1) -- su habitat real.
//   - Jurel ve la serie del dominio de test (D1, D2 o D3) -- testeo espacial.
//
// Si las 3 columnas de SST_c son identicas y todas las de logCHL_c tambien,
// este modelo es matematicamente equivalente al t4b_state_space_full.stan
// original. Es decir: un superset estricto.
//
// Resto: identico al full original (Schaefer multi-stock + Omega LKJ + priors
// stock-especificos para rho_sst y rho_chl). Ver memoria
// project_t4b_fits_completed.md para el historial.
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

  // CAMBIO RESPECTO A FULL: covariables stock-especificas
  matrix[T, S] SST_c;          // SST anomalia centrada (degC) por stock
  matrix[T, S] logCHL_c;       // log(CHL) centrada por stock

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

  vector[S] rho_sst_prior_mean;
  vector<lower=0>[S] rho_sst_prior_sd;
  vector[S] rho_chl_prior_mean;
  vector<lower=0>[S] rho_chl_prior_sd;
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

  cholesky_factor_corr[S] L_Omega;

  vector[S] rho_sst;
  vector[S] rho_chl;

  array[T] vector[S] logB;
}

transformed parameters {
  vector[S] log_r  = log_r_prior_mean  + z_log_r  .* log_r_prior_sd;
  vector[S] log_K  = log_K_prior_mean  + z_log_K  .* log_K_prior_sd;
  vector[S] log_B0 = log_B0_prior_mean + z_log_B0 .* log_B0_prior_sd;
  vector<lower=0>[S] r_base = exp(log_r);
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

  // Prior LKJ
  L_Omega ~ lkj_corr_cholesky(4);

  // Priors shifters (stock-especificos)
  for (s in 1:S) {
    rho_sst[s] ~ normal(rho_sst_prior_mean[s], rho_sst_prior_sd[s]);
    rho_chl[s] ~ normal(rho_chl_prior_mean[s], rho_chl_prior_sd[s]);
  }

  // Dinamica multivariada con shifters ambientales STOCK-ESPECIFICOS
  {
    matrix[S, S] L_proc = diag_pre_multiply(sigma_proc, L_Omega);

    for (s in 1:S) {
      logB[1][s] ~ normal(log_B0[s], sigma_proc[s]);
    }

    for (t in 2:T) {
      vector[S] logB_mean_t;
      for (s in 1:S) {
        // CAMBIO: SST_c[t-1, s] y logCHL_c[t-1, s] -- por stock
        real r_t = r_base[s]
                   * exp(rho_sst[s] * SST_c[t - 1, s]
                       + rho_chl[s] * logCHL_c[t - 1, s]);
        logB_mean_t[s] = schaefer_step_log(logB[t - 1][s], log_K[s], r_t, C[t - 1, s]);
      }
      logB[t] ~ multi_normal_cholesky(logB_mean_t, L_proc);
    }
  }

  // Likelihood
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
  vector<lower=0>[S] r_nat   = r_base;
  vector<lower=0>[S] K_nat   = exp(log_K);
  vector<lower=0>[S] B0_nat  = exp(log_B0);

  corr_matrix[S] Omega = multiply_lower_tri_self_transpose(L_Omega);

  matrix<lower=0>[T, S] B_smooth;
  for (t in 1:T) for (s in 1:S) B_smooth[t, s] = exp(logB[t][s]);

  matrix<lower=0>[T - 1, S] r_eff;
  for (t in 2:T) for (s in 1:S) {
    // CAMBIO: SST_c[t-1, s] y logCHL_c[t-1, s] -- por stock
    r_eff[t - 1, s] = r_base[s]
                      * exp(rho_sst[s] * SST_c[t - 1, s]
                          + rho_chl[s] * logCHL_c[t - 1, s]);
  }

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
