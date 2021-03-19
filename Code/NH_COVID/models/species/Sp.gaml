/**
* Name: Sp
* Based on the internal empty template. 
* Author: jpablo91
* Tags: 
*/

@no_experiment

model Sp

import "../global.gaml"

//===============Species:building============
species Building{
	aspect B_geom{
		draw shape color: #white border:#black;
	}
}

//==========Species:Rooms==========
species Rooms{
	string Type;
	list<Residents> CurrentRes;
	aspect R_geom{
		draw shape color: #white border:#black;
	}
}

//============Species:people================
species People skills:[moving]{
	// DUMMY FOR TEST
//	float A00;
	
	Rooms current_room;
	bool is_active <- true;
	string people_type;
	
	//Disease parameters
	float transmission_p;
	float shedding_p;
	float infection_p;
	bool is_susceptible <- true;
	bool is_infected;
	bool is_infectious;
	bool is_symptomatic;
	bool is_recovered;
	bool hosp_patient; // will the patient require hospitalization?
	bool is_hospitalized; //Are they hospitalized in the same building??
	bool is_isolated;
	float mortality <- BaseMortality;
	// PPE
	float PPE_e <- 1.0;
	int x_PPE;
	
	// Vaccine
	float Vaccine_e <- 1.0;
	float My_Vaccine_OR;
	float x_Vaccine;
	
	
	// vaccination
	bool is_vaccinated;
	int vaccinated_days;
	int vaccine_doses;
	
	// Parameters for equation
//	float t; //Variable to represent the discrete time for integration
//   	float MVi <- Vi_first_dose; //Max Effect
//	float Vi <- 0.01; //initial Immune response
//	float dVi <- MVi - Vi; // Immunity to Max
//	
//  	float vi_rise <- G_Rise; //Rate of rise
//   	float vi_decay <- G_Decay; //Rate of decay
//   	float h <- 1.0;
//   	string mm <- "Euler";
	
	
	string infection_source;
	int hospitalization_t; // time hospitalized 
	int hospitalization_days; // hospitalization days
	int max_hosp_days; // how many days will the resident spend in hospital?
	People infection_agent;
	
	float hospitalization_p;
	Rooms my_bedroom;
	
	
	bool tested;
	bool detected;
	int latent_period;
	
	int infected_t;
	int infected_days;
	
	// ~~~~~~~~ Equations
//	equation eqSIR{ 
//    diff(dVi,t) = (- vi_rise * dVi * Vi / MVi);
//    diff(Vi,t) = (vi_rise * dVi * Vi / MVi) - (vi_decay * Vi);
//    }
	
	//~~~~~~~~ Actions
	action infect{
		ask agents of_generic_species People at_distance infection_distance where(each.is_susceptible){
			if flip(self.infection_p){
				is_infected <- true;
				is_susceptible <- false;
				latent_period <-int(lognormal_trunc_rnd(3, 2, 2, 10));
				if ExportResults{
					save [cycle, name, latent_period] to: "../results/" + "/LP/LatentP" + int(seed) +".csv" type:"csv" rewrite:false;
				}
				infection_source <- "Facility";
				max_hosp_days <- poisson(6.5); // how many days will the resident spend in hospital? (if hospitalized) !!! REPORT on the MODEL description
				infection_agent <- myself;
//				write string(myself) + " Infected " + self + ' at cycle:' + cycle;
				if(self.people_type = 'staff'){
					Cumulative_I_s <- Cumulative_I_s + 1;
				} else if(self.people_type = 'resident'){
					Cumulative_I_r <- Cumulative_I_r + 1;
				}
			 }
			}	
	}
	
	//~~~~~~~~ Reflex
	// wander
	reflex normal_mov when: is_active{
		do wander bounds:geometry(current_room) speed:2#m/#hour;
	}
	// Disease dynamics
	reflex Disease_dynamics{
		// update susceptibility
		float odds_s <- GlobalShedding_p/(1-GlobalShedding_p); // compute the odds of the base probability of transmission [W]
		float shedding_o <- exp(ln(odds_s) + ln(PPE_OR)*x_PPE + ln(My_Vaccine_OR)*x_Vaccine);
		shedding_p <-  shedding_o/(1 + shedding_o); //convert the odds to probability
		
		float odds_i <- GlobalShedding_p/(1-GlobalShedding_p); // compute the odds of the base probability of transmission
		float infection_o <- exp(ln(odds_i) + ln(PPE_OR)*x_PPE + ln(My_Vaccine_OR)*x_Vaccine);
		infection_p <-  infection_o/(1 + infection_o); //convert the odds to probability
		
		
		if is_infected{
			infected_t <- infected_t + 1;
			// ******State transition E -> I
			if infected_t > latent_period*24{ 
				is_infectious <- true;
				is_symptomatic <- true;
				if flip(Asymptomatic_p){
					is_symptomatic <- false;
				}
			}
		}
		
		if is_infectious{
			infected_t <- infected_t + 1;
			if flip(shedding_p) and is_active{
				do infect;
			}
			// ******State Transition I -> H
			if flip(hospitalization_p) and !is_hospitalized{
				// Move to hospital
				is_hospitalized <- true;
				current_room <- first(Rooms where(each.Type = "Therapy"));
				location <- current_room.location;	
				is_active <- false;
				my_bedroom.CurrentRes >- self;
//				write string(self) + "Moved to Hospitalization";
				Cumulative_H <- Cumulative_H + 1;
			}
			// ******State Transition H -> D
			
			
			// ******State Transition I -> R
			if infected_t > Infection_Duration*24{
				is_infected <- false;
				is_infectious <- false;
				is_recovered <- true;
				is_symptomatic <- false;
				infected_t <- 0;
			}
		}
		infected_days <- int(infected_t/24);
		
		// VACCINATION
		if is_vaccinated{
			vaccinated_days <- vaccinated_days + 1;
			
			// Boolean Vaccinaiton decay
			if(vaccinated_days = Revaccination_t*24){
				vaccine_doses <- 2;
//				Vaccine_e <- 1 - Vi_second_dose;
				x_Vaccine <- 1.0;
			}
			if (vaccinated_days > Vaccination_decay){ // vaccine effect decay
				is_vaccinated <- false;
				Vaccine_e <- 1.0;
			}
			
//			// Continous vaccination decay
//			solve eqSIR method: mm step_size:h;
//			
//			if(vaccinated_days = Revaccination_t*24){
//			MVi <- Vi_second_dose;
//			dVi <- MVi -Vi;
//		}
//		if(vaccinated_days = Immunity_decay_t*24){
//			vi_decay <- 0.05;
//		}
		}
	}
}

//=============Subspecies: Residents ============
species Residents parent:People{
	string people_type <- "resident";
	bool attended;
	int StaffInteractions;
	bool hospitalized;
	
	action recreate{
	}
	
	action to_my_room{
//		point target <- my_bedroom.location;
//		do goto target:target;
	}
	
	reflex Switch_Rooms{
		if(Schedule = "Recreation Time" and is_active){
			if RecreationRestrictions{
				current_room <- my_bedroom;
				speed <- 0.001#m/#h;
			}
			if !RecreationRestrictions{
				current_room <- one_of(Rooms where(each.Type = "Recreation")); // !!! Every cycle is runing this, check how to do once per sched change
				speed <- 2#m/#h;	
			}
			
		} if(Schedule = "Eating Time" and is_active){
			if CD_Restriction{
				current_room <- my_bedroom;
				speed <- 0.001#m/#h;
			}
			if !CD_Restriction{
				current_room <- one_of(Rooms where(each.Type = "Dinning Room"));
				speed <- 0.2#m/#h;	
			}
		} if(Schedule = "Quiet Hours" and is_active){
			current_room <- my_bedroom;
			speed <- 0.001#m/#h;
		}
		location <- any_location_in(current_room);
		
		// *** move from isolation back to room
			if is_isolated and !is_infected{
//				my_bedroom <- first(Rooms where((each.Type = "Bedroom") and (length(each.CurrentRes) < 3)));
				my_bedroom <- (Rooms where(each.Type = "Bedroom")) with_min_of(length(each.CurrentRes));
				location <- my_bedroom.location;
				is_isolated <- false;
				my_bedroom.CurrentRes <+ self;
			}
	}
	
	// Hospitalization
	reflex Hospitalization when:is_hospitalized{
		hospitalized <- true;
		hospitalization_t <- hospitalization_t + 1;
		hospitalization_days <- int(hospitalization_t/24);
		if hospitalization_days > max_hosp_days{
			if flip(1 - mortality){
				location <- my_bedroom.location;
				is_active <- true;
				hospitalized <- false;
				hospitalization_t <- 0;
				is_hospitalized <- false;
			} else{
				D <- D + 1;
				do die;
			}
			
		}
		
	}
	
	//~~~~~~~~~~~ Aspect 
	aspect R_geom{
		draw circle(0.3) color:is_infected ? rgb (230, 50, 50,255) : rgb (50, 230, 50, 255);
	}
}

//=============Subspecies: Staff ============
species Staff parent:People{
	/*Staff schedules:
	 * 1 = 7-15; 2 = 15-23; 3 = 23-7
	 */
	 int schedule;
	 string people_type <- 'staff';
	 string Type;
	 bool at_community;
	 int ResTurn;
	 list<Residents> TargetRes;
	 
	 
	 reflex StaffSchedules{
	 	if (current_date.hour between(7, 15) and schedule = 1){
	 		is_active <- true;
	 	} else if (current_date.hour between(15, 23) and schedule = 2){
	 		is_active <- true;
	 	} else if ((current_date.hour between(23, 24) or current_date.hour between(-1, 7))  and schedule = 3){
	 		is_active <- true;
	 	} else{
	 		is_active <- false;
	 	}
	 	
	 	// Go to community
	 	if !is_active{
	 		location <- any_location_in(geometry(community_shp));
	 		at_community <- true;
	 	} else if is_active and at_community{ // Return to the NH
	 	//Report the residents per turn
	 	if ExportResults{
	 		save [cycle, name, Type, ResTurn] to: "../results/" + "/S/RPT" + int(seed) +".csv" type:"csv" rewrite:false;
	 	}
	 		current_room <- one_of(Rooms where(each.Type = "Staff"));
			location <- any_location_in(current_room);
			ResTurn <- 0;
			at_community <- false;
			if flip(Introduction_p/100){
				is_infected <- true;
				infection_source <- "Community";
				Cumulative_I_s <- Cumulative_I_s + 1;
			}
	 	}
	 }
	 
	 reflex PatientInteraction when:is_active{
	 	int ResSeen;
	 	// Pick up a number of residents to interact in a given hour
	 	if Type = 'CN'{
	 		ResSeen <- rnd_choice(PPH_CN);	
	 		ResTurn <- ResTurn + ResSeen;
	 	} else if Type = 'RN'{
	 		ResSeen <- rnd_choice(PPH_RN);
	 		ResTurn <- ResTurn + ResSeen;
	 	} else if Type = 'LPN'{
	 		ResSeen <- rnd_choice(PPH_LPN);
	 		ResTurn <- ResTurn + ResSeen;
	 	}
	 	
//	 	TargetRes <- sample(list(Residents where !each.is_isolated), ResSeen, false); // !!! we are ignoring the isolated residents how can we deal with this??
	 	TargetRes <- sample(list(Residents where each.is_active), ResSeen, false);
	 	ask TargetRes{
	 		attended <- true;
	 		StaffInteractions <- StaffInteractions + 1;
	 		// Staff to resident transmission
	 		if myself.is_infectious and !self.is_infected{
	 			if flip(myself.shedding_p){
	 				if flip(self.infection_p){
	 					self.is_infected <- true;
	 					infection_source <- 'staff';
	 					Cumulative_I_r <- Cumulative_I_r + 1;
//	 					write string(myself) + ' Infected ' + self + ' at cycle:' + cycle;
	 				}
	 				
	 			}
	 		}
	 		
	 		// Resident to staff transmission
	 		if self.is_infectious and !myself.is_infected{
	 			if self.is_isolated{ // assuming there is a correct use of PPE
	 				if flip(self.shedding_p){
	 					if flip(myself.infection_p/5){
	 						myself.is_infected <- true;
	 						Cumulative_I_s <- Cumulative_I_s + 1;
	 					}
	 					
	 				}
	 			} else if !self.is_isolated{
	 				if flip(self.shedding_p*myself.infection_p){
	 					myself.is_infected <- true;
	 					Cumulative_I_s <- Cumulative_I_s + 1;
	 				}
	 			}
	 			
	 		}
	 	}
	 	//Empty the list after each time step
	 	TargetRes <- [];
	 }
	 
	 
	 //~~~~~~~~~~~ Aspect 
	aspect S_geom{
		if is_active{
			draw circle(0.3) color:is_infected ? rgb (150, 25, 25,255) : rgb (25, 150, 25, 255);
		} else{
			draw circle(0.3) color:rgb (25, 150, 25, 100);
		}
		
	}
}

/* Insert your model definition here */
