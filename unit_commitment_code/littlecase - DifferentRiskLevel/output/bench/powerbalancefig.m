data(:,1) = load("res_thermalunits.txt");
data(:,2) = load("res_windunits.txt");
data(:,3) = load("res_forcedloadcurtailment.txt");
data(:,4) = load("res_BESS_discharging.txt");
data(:,5) = -load("res_BESS_charging.txt");

createfigure(data);
