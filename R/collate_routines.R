#use_cfac_type_in_sim = TRUE

run_collate_routines <- function(simulation_outputs, current_trajectories, decline_rates_initial, initial_feature_layers, 
                                 current_data_dir, combination_params, realisation_ind, feature_ind){
  
    current_decline_rates_initial = select_nested_subset(nested_object = decline_rates_initial, 
                                                         nested_ind = feature_ind, output_type = 'nested')
    current_initial_feature_layers = select_nested_subset(nested_object = initial_feature_layers, 
                                                   nested_ind = feature_ind, output_type = 'nested')
    
    landscape_cfacs_object = collate_cfacs(combination_params,
                                           current_parcel_feature_layers = current_initial_feature_layers,
                                           current_decline_rates = current_decline_rates_initial, 
                                           current_offset_yrs = rep(1, length(current_initial_feature_layers)), 
                                           current_parcel_num_remaining = vector(),
                                           cfac_type = 'landscape',
                                           collate_type = vector(), 
                                           use_cfac_type_in_sim = FALSE, 
                                           feature_ind = 1) #set to feature_ind = 1 as at this point there is only 1 selected feature
    
    collated_data = collate_simulation_outputs(simulation_outputs, current_trajectories, 
                                            landscape_cfacs_object, current_decline_rates_initial, current_initial_feature_layers, 
                                            combination_params, use_cfac_type_in_sim = TRUE, parcels, feature_ind)
    
    return(collated_data)
  
}


calc_landscape_characteristics <- function(current_trajectories, landscape_cfacs_object){
  landscape_object = list()
  landscape_object$summed_site_trajectories = lapply(seq_along(current_trajectories), function(i) sum_cols(current_trajectories[[i]]))
  landscape_object$net_landscape = Reduce('+', landscape_object$summed_site_trajectories)
  landscape_object$landscape_cfacs = landscape_cfacs_object$net_background_cfacs
  landscape_object$landscape_impact = landscape_object$net_landscape - landscape_cfacs_object$net_background_cfacs
  return(landscape_object)
}


find_collated_files <- function(file_path, scenario_string, feature_string, realisation_num){
  scenario_filenames <- list.files(path = file_path, all.files = FALSE, 
                                   pattern = paste0('scenario_', scenario_string),
                                   full.names = FALSE, recursive = FALSE, ignore.case = FALSE, 
                                   include.dirs = FALSE, no.. = FALSE)
  
  feature_filenames <- list.files(path = file_path, all.files = FALSE, 
                                  pattern = paste0('feature_', feature_string),
                                  full.names = FALSE, recursive = FALSE, ignore.case = FALSE, 
                                  include.dirs = FALSE, no.. = FALSE)
  
  current_filenames = intersect(feature_filenames, scenario_filenames)
  net_realisation_num = length(current_filenames)
  
  if (realisation_num == 'all'){
    realisation_num = net_realisation_num
  } 
  
  if (net_realisation_num == 0){
    stop(paste0('\n ERROR: No files found for scenario ', scenario_string, ', feature ', feature_string, ' in ', file_path))
  } 
  
  if (net_realisation_num < realisation_num){
    realisation_num = net_realisation_num
    print(paste0('WARNING: Only found ', realisation_num, ' realisation files for scenario ', scenario_string, ', feature ', feature_string, ', in ', file_path))
  }

  
  filenames_to_use = current_filenames[seq(realisation_num)]
  filenames_to_use = lapply(seq_along(filenames_to_use), function(i) paste0(file_path, '/', filenames_to_use[i]))
  
  return(filenames_to_use)
}

bind_collated_realisations <- function(collated_filenames){
  realisation_num = length(collated_filenames)
  
  for (realisation_ind in seq(realisation_num)){
    current_collated_realisation = readRDS(collated_filenames[[realisation_ind]])
    if (realisation_ind == 1){
      collated_realisations = lapply(seq_along(current_collated_realisation), 
                                     function(i) nest_list(current_collated_realisation[[i]]))
    } else {
      collated_realisations <- lapply(seq_along(current_collated_realisation), 
                                      function(i) append_nested_realisation(collated_realisations[[i]], current_collated_realisation[[i]], realisation_ind))
    }
    names(collated_realisations) = names(current_collated_realisation)
  }
  
  collated_realisations$realisation_num = realisation_num
  return(collated_realisations)
}


nest_list <- function(list_a){
  nested_list = lapply(seq_along(list_a), function(j) list(list_a[[j]]))
  names(nested_list) = names(list_a)
  return(nested_list)
}

expand_current_collated_realisation <- function(expand_type, collated_object, net_names, realisation_ind){
  expanded_collated_object = vector('list', length(net_names))
  common_inds = (match(names(collated_object), net_names))
  new_inds = setdiff(seq_along(net_names), common_inds)
  expanded_collated_object[common_inds] = collated_object
  if (expand_type == 'set'){
    expanded_collated_object[new_inds] = lapply(seq_along(new_inds), function(i) vector('list', realisation_ind - 1))
  } else {
    expanded_collated_object[new_inds] = lapply(seq_along(new_inds), function(i) vector('list', 1))
  }
  names(expanded_collated_object) = net_names
  return(expanded_collated_object)
}


append_nested_realisation <- function(collated_set, collated_element, realisation_ind){
  
  net_names = union(names(collated_set), names(collated_element))

  collated_set = expand_current_collated_realisation(expand_type = 'set', collated_set, net_names, realisation_ind)
  collated_element = expand_current_collated_realisation(expand_type = 'single', collated_element, net_names, realisation_ind)
  
  appended_object = append_nested_object(collated_set, collated_element)
  return(appended_object)
  
}

append_nested_object <- function(object_a, object_b){
  
  appended_object <- lapply(seq_along(object_a), function(j) append(object_a[[j]], list(object_b[[j]])))
  names(appended_object) = names(object_b)
  return(appended_object)  
}

merge_lists <- function(list_a, list_b, merge_indexes){
  merged_list <- lapply(seq_along(list_a),
                        function(i) merge_vectors(list_a[[i]], list_b[[i]], merge_indexes[i]))
  return(merged_list)
}


#background_cfacs = landscape_cfacs_object$background_cfacs

collate_program_cfacs <- function(simulation_outputs, background_cfacs, collated_offsets, collated_devs, collated_dev_credit, 
                                  collated_offset_bank, collated_unregulated_loss){
  
  program_cfacs_object = list()
  program_cfacs_object$offset_cfacs <- merge_lists(background_cfacs[unlist(simulation_outputs$offsets_object$site_indexes)], collated_offsets$cfacs, unlist(simulation_outputs$offsets_object$offset_yrs))
  program_cfacs_object$dev_cfacs <- merge_lists(background_cfacs[unlist(simulation_outputs$dev_object$site_indexes)], collated_devs$cfacs, unlist(simulation_outputs$dev_object$offset_yrs))
  program_cfacs_object$dev_credit_cfacs <- merge_lists(background_cfacs[unlist(simulation_outputs$credit_object$site_indexes)], collated_dev_credit$cfacs, unlist(simulation_outputs$credit_object$offset_yrs))
  program_cfacs_object$offset_bank_cfacs <- merge_lists(background_cfacs[unlist(simulation_outputs$offset_bank_object$site_indexes)], collated_offset_bank$cfacs, unlist(simulation_outputs$offset_bank_object$offset_yrs))
  
  cfac_sums = list(program_cfacs_object$offset_cfacs, program_cfacs_object$dev_cfacs, program_cfacs_object$dev_credit_cfacs, program_cfacs_object$offset_bank_cfacs)
  cfacs_to_use = unlist(lapply(seq_along(cfac_sums), function(i) length(cfac_sums[[i]]))) > 0
  
  program_cfacs_object$program_cfac_sum <- Reduce('+', unlist(cfac_sums[cfacs_to_use], recursive = FALSE))
  
  return(program_cfacs_object)
  
}




# current_parcel_feature_layers = current_initial_feature_layers
# current_decline_rates = current_decline_rates_initial 
# current_offset_yrs = rep(1, length(current_initial_feature_layers)) 
# current_parcel_num_remaining = vector()
# cfac_type = 'landscape'
# collate_type = vector() 
# use_cfac_type_in_sim = FALSE

collate_cfacs <- function(combination_params, current_parcel_feature_layers, current_decline_rates, current_offset_yrs, 
                          current_parcel_num_remaining, cfac_type, collate_type, use_cfac_type_in_sim, feature_ind){
  
  cfac_params <- select_cfac_type(collate_type, use_cfac_type_in_sim, combination_params)
  
  parcel_count = length(current_parcel_feature_layers)
  
  if (cfac_type == 'landscape'){                    
    time_horizons <- generate_time_horizons(project_type = 'future', 
                                            yr = 1, 
                                            offset_yrs = rep(1, parcel_count), 
                                            time_horizon = (combination_params$time_steps - 1), 
                                            parcel_count)
    adjust_cfacs_flag = TRUE
    include_potential_developments = FALSE
    include_potential_offsets = FALSE
    include_unregulated_loss = TRUE
    
  } else {
    time_horizons = generate_time_horizons(project_type = 'current', 
                                           yr = combination_params$time_steps, 
                                           offset_yrs = current_offset_yrs, 
                                           time_horizon = (combination_params$time_steps - 1), 
                                           parcel_count)
    adjust_cfacs_flag = cfac_params$adjust_cfacs_flag
    include_potential_developments = cfac_params$include_potential_developments
    include_potential_offsets = cfac_params$include_potential_offsets
    include_unregulated_loss = cfac_params$include_unregulated_loss
  }
  
  cfacs_object = calc_cfacs(parcel_feature_layers = current_parcel_feature_layers, 
                            parcel_num_remaining = current_parcel_num_remaining,
                            combination_params,
                            current_decline_rates, 
                            time_horizons, 
                            offset_yrs = current_offset_yrs, 
                            include_potential_developments,
                            include_potential_offsets,
                            include_unregulated_loss,
                            adjust_cfacs_flag,
                            features_to_project = 1)
  
  if (cfac_type == 'landscape'){
    background_cfacs = lapply(seq_along(cfacs_object$cfacs), function(i) cfacs_object$cfacs[[i]][[1]])    #extract from nested list
    cfacs_object$background_cfacs = lapply(seq_along(background_cfacs), function(i) sum_cols(background_cfacs[[i]]))
    cfacs_object$net_background_cfacs = Reduce('+', cfacs_object$background_cfacs)
    cfacs_object$net_cfacs_including_clearing = Reduce('+', lapply(seq_along(cfacs_object$cfacs_to_use), function(i) cfacs_object$cfacs_to_use[[i]][[1]]))
  } else {
    if (adjust_cfacs_flag == TRUE){
      cfacs_object$cfacs = lapply(seq_along(cfacs_object$adjusted_cfacs), function(i) cfacs_object$adjusted_cfacs[[i]][[1]])    #extract from nested list
    } else {
      cfacs_object$cfacs = lapply(seq_along(cfacs_object$cfacs), function(i) cfacs_object$cfacs[[i]][[1]])    #extract from nested list
    }
  }
  
  return(cfacs_object)
}


collate_program_scale_outcomes <- function(simulation_outputs, summed_site_trajectories){
  program_scale_outcomes = list()
  program_scale_outcomes$offsets <- Reduce('+', summed_site_trajectories[unlist(simulation_outputs$offsets_object$site_indexes)])
  program_scale_outcomes$devs <- Reduce('+', summed_site_trajectories[unlist(simulation_outputs$dev_object$site_indexes)])
  program_scale_outcomes$dev_credit <- Reduce('+', summed_site_trajectories[unlist(simulation_outputs$credit_object$site_indexes)])
  program_scale_outcomes$offset_bank <- Reduce('+', summed_site_trajectories[unlist(simulation_outputs$offset_bank$site_indexes)])
  
  program_scale_outcomes$net_offsets <- sum_list(list(program_scale_outcomes$offsets, program_scale_outcomes$offset_bank))
  program_scale_outcomes$net_devs <- sum_list(list(program_scale_outcomes$devs, program_scale_outcomes$dev_credit))
  program_scale_outcomes$net_outcome <- sum_list(list(program_scale_outcomes$net_offsets, program_scale_outcomes$net_devs))
  
  return(program_scale_outcomes)
}




collate_program_scale_impacts <- function(collated_data){
  program_scale_impacts = list()
  program_scale_impacts$offset_site_gains = Reduce('+', collated_data$collated_offsets$summed_gains_degs$nets)
  program_scale_impacts$offset_bank_gains = Reduce('+', collated_data$collated_offset_bank$summed_gains_degs$nets)
  program_scale_impacts$dev_site_losses = Reduce('+', collated_data$collated_devs$summed_gains_degs$nets)
  program_scale_impacts$dev_credit_losses = Reduce('+', collated_data$collated_dev_credit$summed_gains_degs$nets)
  program_scale_impacts$unregulated_loss <- Reduce('+', collated_data$collated_unregulated_loss$summed_gains_degs$nets)
  
  program_scale_impacts$net_offset_gains = sum_list(list(program_scale_impacts$offset_site_gains, program_scale_impacts$offset_bank_gains))
  program_scale_impacts$net_dev_losses = sum_list(list(program_scale_impacts$dev_site_losses, program_scale_impacts$dev_credit_losses))
  program_scale_impacts$program_total <- sum_list(list(program_scale_impacts$net_offset_gains, program_scale_impacts$net_dev_losses))
  return(program_scale_impacts)
}





run_site_scale_collate_routine <- function(current_model_outputs, current_site_groups, current_trajectories, current_decline_rates_initial, 
                                           collate_type, combination_params, use_cfac_type_in_sim, feature_ind){
  
  collated_object = list()
  collated_object = collate_gains_degs(current_model_outputs, 
                                       current_trajectories,
                                       current_decline_rates_initial ,
                                       collate_type, 
                                       combination_params,
                                       use_cfac_type_in_sim, 
                                       feature_ind)
  
  if (length(collated_object) > 0){
    collated_object$grouped_gains_degs = group_gains_degs(collated_object, current_site_groups)
    collated_object$summed_gains_degs = sum_gains_degs(collated_object$grouped_gains_degs)
    collated_object$site_indexes = current_site_groups
    collated_object$offset_yrs = current_model_outputs$offset_yrs
  } else {
    collated_object = list()
  }
  return(collated_object)
}



sum_gains_degs <- function(grouped_gains_degs){
  summed_gains_degs <- lapply(seq_along(grouped_gains_degs), 
                              function(i) (lapply(seq_along(grouped_gains_degs[[i]]), function(j) Reduce('+', grouped_gains_degs[[i]][[j]]))))
  
  names(summed_gains_degs) = names(grouped_gains_degs) 
  
  return(summed_gains_degs)
}



group_gains_degs <- function(collated_object, site_indexes){ 
  
  grouped_gains_degs <- lapply(seq_along(collated_object), 
                               function(i) (lapply(seq_along(site_indexes), 
                                                   function(j) collated_object[[i]][which(unlist(site_indexes) 
                                                                                          %in% site_indexes[[j]])])))
  names(grouped_gains_degs) = names(collated_object)
  
  return(grouped_gains_degs)
  
}


collate_gains_degs <- function(current_model_outputs, current_trajectories, current_decline_rates_initial, 
                               collate_type, combination_params, use_cfac_type_in_sim, feature_ind){ 
  
  
  if (length(unlist(current_model_outputs$site_indexes)) == 0){
    return(NULL)
  }
  
  current_parcel_feature_layers = select_nested_subset(nested_object = current_model_outputs$parcel_feature_layers, nested_ind = feature_ind, output_type = 'nested') 
  
  current_cfacs = collate_cfacs(combination_params, 
                                current_parcel_feature_layers,
                                current_decline_rates = current_decline_rates_initial[unlist(current_model_outputs$site_indexes)], 
                                current_offset_yrs =  unlist(current_model_outputs$offset_yrs),
                                current_parcel_num_remaining = current_model_outputs$parcel_num_remaining,
                                cfac_type = 'site_scale',
                                collate_type, 
                                use_cfac_type_in_sim,
                                feature_ind = 1)
  
  parcel_feature_layers_to_use = select_nested_subset(nested_object = current_model_outputs$parcel_feature_layers, nested_ind = feature_ind, output_type = 'non-nested') 
  
  collated_gains_degs <- assess_gains_degs(trajectories_to_use = current_trajectories[unlist(current_model_outputs$site_indexes)],
                                           cfacs_to_use = current_cfacs$cfacs,
                                           parcel_feature_layers_to_use,
                                           current_offset_yrs = unlist(current_model_outputs$offset_yrs),
                                           collate_type, 
                                           combination_params,
                                           time_steps = combination_params$time_steps)
  
  collated_gains_degs$cfacs = lapply(seq_along(current_cfacs$cfacs_to_use), function(i) current_cfacs$cfacs_to_use[[i]][[1]])
  
  return(collated_gains_degs)
  
}



merge_vectors <- function(vec_a, vec_b, start_ind){
  vec_a[start_ind:(start_ind + length(vec_b) - 1)] = vec_b
  return(vec_a)
}


assess_gains_degs <- function(trajectories_to_use, cfacs_to_use, parcel_feature_layers_to_use, current_offset_yrs, collate_type, combination_params, time_steps){
  
  tmp_object = list()
  parcel_num = length(trajectories_to_use)
  
  impact_trajectories = lapply(seq(parcel_num), function(i) sum_cols(trajectories_to_use[[i]][current_offset_yrs[i]:time_steps, ]))
  
  tmp_object$nets = lapply(seq(parcel_num), function(i) impact_trajectories[[i]] - sum_cols(cfacs_to_use[[i]]))
  
  tmp_object$rest_gains = lapply(seq(parcel_num), function(i) impact_trajectories[[i]] - sum(parcel_feature_layers_to_use[[i]]))
  
  tmp_object$avoided_loss = lapply(seq(parcel_num), function(i) sum(parcel_feature_layers_to_use[[i]]) - sum_cols(cfacs_to_use[[i]]))
  
  collated_object <- lapply(seq_along(tmp_object),
                            function(i) lapply(seq_along(tmp_object[[i]]), 
                                               function(j) merge_vectors(array(0, time_steps), tmp_object[[i]][[j]], current_offset_yrs[j])))
  names(collated_object) = names(tmp_object)
  
  if ((collate_type == 'offsets') | (collate_type == 'offset_bank')){
    if (combination_params$offset_calc_type == 'restoration_gains'){
      collated_object$nets = collated_object$rest_gains
    } else if (combination_params$offset_calc_type == 'avoided_loss'){
      collated_object$nets = collated_object$avoided_loss
    } else if (combination_params$offset_calc_type == 'net_gains'){
      collated_object$nets = collated_object$nets
    }
  } else {
    if (combination_params$dev_calc_type == 'future_condition'){
      collated_object$nets = collated_object$nets
    } else if (combination_params$dev_calc_type == 'current_condition'){
      collated_object$nets = collated_object$rest_gains
    }
    
  }
  
  return(collated_object)
}



select_nested_subset <- function(nested_object, nested_ind, output_type){
  
  if (output_type == 'nested'){
    nested_subset_object <- lapply(seq_along(nested_object), function(i) nested_object[[i]][nested_ind])
  } else {
    nested_subset_object <- lapply(seq_along(nested_object), function(i) nested_object[[i]][[nested_ind]])
  }
  return(nested_subset_object)
}


collate_simulation_outputs <- function(simulation_outputs, current_trajectories, landscape_cfacs_object, 
                            current_decline_rates_initial, current_initial_feature_layers, combination_params, use_cfac_type_in_sim, parcels, feature_ind){
  
  collated_data = list()
  
  collated_data$collated_offsets <- run_site_scale_collate_routine(current_model_outputs = simulation_outputs$offsets_object,
                                                                      current_site_groups = simulation_outputs$index_object$site_indexes_used$offsets,
                                                                      current_trajectories, 
                                                                      current_decline_rates_initial, 
                                                                      collate_type = 'offsets', 
                                                                      combination_params,
                                                                      use_cfac_type_in_sim, 
                                                                      feature_ind)
  
  collated_data$collated_devs = run_site_scale_collate_routine(current_model_outputs = simulation_outputs$dev_object,
                                                                  current_site_groups = simulation_outputs$index_object$site_indexes_used$devs,
                                                                  current_trajectories, 
                                                                  current_decline_rates_initial, 
                                                                  collate_type = 'devs', 
                                                                  combination_params,
                                                                  use_cfac_type_in_sim, 
                                                                  feature_ind)
  
  collated_data$collated_dev_credit = run_site_scale_collate_routine(current_model_outputs = simulation_outputs$credit_object, 
                                                                        current_site_groups = simulation_outputs$index_object$site_indexes_used$dev_credits,
                                                                        current_trajectories, 
                                                                        current_decline_rates_initial, 
                                                                        collate_type = 'dev_credit', 
                                                                        combination_params,
                                                                        use_cfac_type_in_sim, 
                                                                        feature_ind)
  
  collated_data$collated_offset_bank = run_site_scale_collate_routine(current_model_outputs = simulation_outputs$offset_bank_object, 
                                                                         current_site_groups = simulation_outputs$index_object$site_indexes_used$banking,
                                                                         current_trajectories, 
                                                                         current_decline_rates_initial, 
                                                                         collate_type = 'offset_bank', 
                                                                         combination_params,
                                                                         use_cfac_type_in_sim, 
                                                                         feature_ind)
  
  collated_data$collated_unregulated_loss = run_site_scale_collate_routine(current_model_outputs = simulation_outputs$unregulated_loss_object,
                                                                              current_site_groups = simulation_outputs$index_object$site_indexes_used$unregulated,
                                                                              current_trajectories, 
                                                                              current_decline_rates_initial, 
                                                                              collate_type = 'unregulated_loss', 
                                                                              combination_params,
                                                                              use_cfac_type_in_sim, 
                                                                              feature_ind)
  
  collated_data$site_scale_impacts <- collate_site_scale_impacts(collated_site_scale_offsets = collated_data$collated_offsets$summed_gains_degs$nets,
                                                   collated_site_scale_devs = collated_data$collated_devs$summed_gains_degs$nets)

  collated_data$landscape <- calc_landscape_characteristics(current_trajectories, landscape_cfacs_object)
  
  collated_data$program_outcomes <- collate_program_scale_outcomes(simulation_outputs, collated_data$landscape$summed_site_trajectories)
  
  collated_data$program_scale_impacts <- collate_program_scale_impacts(collated_data)
  
  collated_data$program_cfacs = collate_program_cfacs(simulation_outputs, 
                                                         landscape_cfacs_object$background_cfacs, 
                                                         collated_data$collated_offsets, 
                                                         collated_data$collated_devs, 
                                                         collated_data$collated_dev_credit, 
                                                         collated_data$collated_offset_bank, 
                                                         collated_data$collated_unregulated_loss)
  
  collated_data$site_scale_NNL = assess_collated_NNL(assess_type = 'site_scale', 
                                         impacts = collated_data$site_scale_impacts$net_impacts, 
                                         offset_yrs_to_use = collated_data$collated_offsets$offset_yrs, 
                                         site_indexes = simulation_outputs$index_object$site_indexes_used$offsets)
  
  collated_data$program_scale_NNL = assess_collated_NNL(assess_type = 'program', 
                                            impacts = list(collated_data$program_scale_impacts$program_total), 
                                            offset_yrs_to_use = list(1), 
                                            site_indexes = vector())
  
  collated_data$landscape_scale_NNL = assess_collated_NNL(assess_type = 'landscape', 
                                              impacts = list(collated_data$landscape$landscape_impact), 
                                              offset_yrs_to_use = list(1), 
                                              site_indexes = vector())
  
  collated_data$net_program_loss = assess_landscape_loss(landscape_vals = collated_data$program_outcomes$net_outcome, 
                                                            NNL_yr = unlist(collated_data$program_scale_NNL$NNL))
  
  collated_data$net_landscape_loss = assess_landscape_loss(landscape_vals = collated_data$landscape$net_landscape, 
                                                              NNL_yr = unlist(collated_data$landscape_scale_NNL$NNL))
  
  collated_data$sites_used = find_sites_used(collated_data)
  return(collated_data)
  
}


# offset_yrs = collated_realisations$collated_offsets$offset_yrs
# offset_sites_used = lapply(seq_along(offset_yrs), function(i) length(offset_yrs[[i]]))
# dev_sites_used = lapply(seq_along(dev_yrs), function(i) length(dev_yrs[[i]]))
# net_sites_used = sum_lists(offset_sites_used, dev_sites_used)
# lapply(seq_along(net_sites_used), function(i) net_sites_used[[i]] > length(parcels$land_parcels))


find_sites_used <- function(collated_data){
  sites_used = list()
  sites_used$offsets = find_current_sites_used(collated_data$collated_offsets$site_indexes)
  sites_used$devs = find_current_sites_used(collated_data$collated_devs$site_indexes)
  
  sites_used$offset_bank = find_current_sites_used(collated_data$collated_offset_bank$site_indexes)
  sites_used$dev_credit = find_current_sites_used(collated_data$collated_dev_credit$site_indexes)
  
  sites_used$unregulated = find_current_sites_used(collated_data$collated_unregulated_loss$site_indexes)
   
  return(sites_used)
}

find_current_sites_used <- function(current_sites_list){
  if (length(current_sites_list) == 0){
    sites_used = list()
    return(sites_used)
  } else {
    sites_used = length(unlist(current_sites_list))
    return(sites_used)
  }
}




collate_site_scale_impacts <- function(collated_site_scale_offsets, collated_site_scale_devs){
  site_scale_impacts = list()
  if ((length(collated_site_scale_offsets) > 0) & (length(collated_site_scale_devs) > 0)){
    site_scale_impacts$net_impacts <- mapply('+', collated_site_scale_offsets, collated_site_scale_devs, SIMPLIFY = FALSE)
  } else {
    site_scale_impacts = list()
  }
  
  return(site_scale_impacts)
}

get_current_sim_characteristics <- function(current_combination_params, realisation_num){
  
  sim_characteristics = vector()
  sim_characteristics = paste0(sim_characteristics, current_combination_params$offset_calc_type, '_')
  sim_characteristics = paste0(sim_characteristics, 'offset_bank_', current_combination_params$use_offset_bank, '_')
  if ((current_combination_params$use_offset_time_horizon == TRUE) & (current_combination_params$use_offset_bank == FALSE)){                                   
    sim_characteristics = paste0(sim_characteristics, 'time_horizon_', current_combination_params$offset_time_horizon)
  }
  sim_characteristics = paste0(sim_characteristics, '_include_unregulated_loss_', current_combination_params$include_unregulated_loss_in_offset_calc)
  
  sim_characteristics = paste0(sim_characteristics, '_reals_', realisation_num, '_')
  #   sim_characteristics = paste0(current_combination_params$offset_calc_type, '_', current_combination_params$dev_calc_type, '_', current_combination_params$cfac_type_in_offset_calc,  '_cfac_offset_bank_', 
  #                                current_combination_params$use_offset_bank, '_')
  #   
  #   if (current_combination_params$use_offset_bank == TRUE){                                   
  #     sim_characteristics = paste0(sim_characteristics, current_combination_params$offset_bank_start, '_', current_combination_params$offset_bank_end, '_', 
  #                                  current_combination_params$offset_bank_num, '_', current_combination_params$match_type)
  #   }
  #   
  #   sim_characteristics = paste0(sim_characteristics, '_', current_combination_params$offset_action_type, '_')
  #   if (current_combination_params$offset_action_type == 'restore'){
  #     sim_characteristics = paste0(sim_characteristics, current_combination_params$restoration_rate, '_')
  #   }
  #   
  #   if (current_combination_params$use_offset_time_horizon == TRUE){                                   
  #     sim_characteristics = paste0(sim_characteristics, '_time_horizon_', current_combination_params$offset_time_horizon)
  #   }
  
  
  #  sim_characteristics = paste0(sim_characteristics, '_offsets_potential_developments_', current_combination_params$include_potential_developments_in_offset_calc)
  
  #  sim_characteristics = paste0(sim_characteristics, '_offsets_potential_offsets_', current_combination_params$include_potential_offsets_in_offset_calc)
  
  #  sim_characteristics = paste0(sim_characteristics, '_devs_unregulated_loss_', current_combination_params$include_unregulated_loss_in_dev_calc)
  
  # sim_characteristics = paste0(sim_characteristics, '_devs_potential_developments_', current_combination_params$include_potential_developments_in_dev_calc)
  
  #  sim_characteristics = paste0(sim_characteristics, '_devs_potential_offsets_', current_combination_params$include_potential_offsets_in_dev_calc)
  
  
  return(sim_characteristics)
}

sum_list <- function(list_to_sum){
  empties = which(unlist(lapply(seq_along(list_to_sum), function(i) length(list_to_sum[[i]]) == 0)))
  sets_to_use = setdiff(seq_along(list_to_sum), empties)
  if (length(sets_to_use) == 0){
    summed_list = list()
  } else {
    summed_list <- Reduce('+', list_to_sum[sets_to_use])
  }
  return(summed_list)
}


find_list_mean <- function(list_to_sum){
  empties = which(unlist(lapply(seq_along(list_to_sum), function(i) length(list_to_sum[[i]]) == 0)))
  sets_to_use = setdiff(seq_along(list_to_sum), empties)
  if (length(sets_to_use) == 0){
    list_mean = list()
  } else {
      list_mean <- Reduce('+', list_to_sum[sets_to_use])/length(sets_to_use)
  }
  return(list_mean)
}

prepare_realisations <- function(realisations){   #remove unsuccessful offset programs
  offset_success_flag = unlist(lapply(seq_along(realisations), function(i) realisations[[i]]$offset_success_flag))
  success_inds = which(offset_success_flag == TRUE)
  realisations <- lapply(success_inds, function(i) realisations[[i]])
  return(realisations)
}



assess_NNL <- function(current_impacts){
  potential_NNL <- which(current_impacts > 0)
  for (NNL_yr in potential_NNL){
    if (all(current_impacts[NNL_yr:length(current_impacts)] > 0)){
      return(NNL_yr)
      break
    }
  }
  NNL_yr = vector()
  return(NNL_yr)
}


assess_collated_NNL <- function(assess_type, impacts, offset_yrs_to_use, site_indexes){
  NNL_object <- list()
  
  if (length(unlist(impacts)) == 0){
    return(NNL_object)
  }
  
  if (assess_type == 'site_scale'){
    site_indexes_to_use = unlist(lapply(seq_along(site_indexes), function(i) which(unlist(site_indexes) == site_indexes[[i]][[1]])))
    offset_yrs_to_use = offset_yrs_to_use[site_indexes_to_use]
  } 
  
  NNL_absolute = lapply(seq_along(impacts), function(i) assess_NNL(impacts[[i]]) )
  
  NNL_object$NNL = lapply(seq_along(NNL_absolute), function(i) (NNL_absolute[[i]] - offset_yrs_to_use[[i]]))
  NNL_object$NNL_success = length(unlist(NNL_object$NNL))/length(NNL_object$NNL)
  
  if (length(unlist(NNL_object$NNL)) >0){
    NNL_object$NNL_mean = mean(unlist(NNL_object$NNL))
  } else {
    NNL_object$NNL_mean = vector()
  }
  
  return(NNL_object)
}


assess_landscape_loss <- function(landscape_vals, NNL_yr){
  landscape_loss = list()
  if (length(NNL_yr)>0){
    landscape_loss$NNL_loss = 1 - landscape_vals[NNL_yr]/landscape_vals[1]
  }
  landscape_loss$total_loss = 1 - landscape_vals[length(landscape_vals)]/landscape_vals[1]
  return(landscape_loss)
}


select_cfac_type <- function(collate_type, use_cfac_type_in_sim, combination_params){
  cfac_params = list()
  
  if (use_cfac_type_in_sim == FALSE){
    include_unregulated_loss = FALSE
    include_potential_developments = FALSE
    include_potential_offsets = FALSE
    adjust_cfacs_flag = FALSE
  } else {
    
    if ((collate_type == 'devs') | (collate_type == 'dev_credit')){
      include_unregulated_loss = combination_params$include_unregulated_loss_in_dev_calc
      include_potential_developments = combination_params$include_potential_developments_in_dev_calc
      include_potential_offsets = combination_params$include_potential_offsets_in_dev_calc
      adjust_cfacs_flag = combination_params$adjust_dev_cfacs_flag
    } else {
      include_unregulated_loss = combination_params$include_unregulated_loss_in_offset_calc
      include_potential_developments = combination_params$include_potential_developments_in_offset_calc
      include_potential_offsets = combination_params$include_potential_offsets_in_offset_calc
      adjust_cfacs_flag = combination_params$adjust_offset_cfacs_flag
    }
  }
  cfac_params$include_unregulated_loss = include_unregulated_loss
  cfac_params$include_potential_developments = include_potential_developments
  cfac_params$include_potential_offsets = include_potential_offsets
  cfac_params$adjust_cfacs_flag = adjust_cfacs_flag
  return(cfac_params)
}




sum_cols <- function(array_to_sum){
  
  if (length(dim(array_to_sum)) <= 1){
    summed_array = sum(array_to_sum)
  } else if (length(dim(array_to_sum)) == 2){
    summed_array = apply(array_to_sum, MARGIN = 1, sum)
  } else if (length(dim(array_to_sum)) == 3){
    summed_array = apply(array_to_sum, MARGIN = c(1, 3), sum)
    dim(summed_array) = c(dim(summed_array), 1)
    summed_array = aperm(summed_array, c(1, 3, 2))
  }
  return(summed_array)
}


threshold_array <- function(arr_in, thresh_level){
  thresh_array = rep(thresh_level, length(arr_in))
  dim(thresh_array) = dim(arr_in)
  arr_out = arr_in * (abs(arr_in) > thresh_array)
  return(arr_out)
}





