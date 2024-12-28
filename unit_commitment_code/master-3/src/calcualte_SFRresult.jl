using MAT
# flag: with/without BESS/withBESSandWinds
# signal: with/with small/large uncertain errors
function form_SFRcurveData(signal, flag)
	if flag == 1
		if signal == 1
			xdata = collect(0:0.05:60)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_positor, δf_actual, δf_samplieddata = simulate(generate_data, particle_filter, 100, 60, 1, 1, 0, 1234)
			δf_ASFR = δf_positor

			str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/data/withoutBESSandWinds/realdata1.mat")
			realoutdata = zeros(1201, 1)
			realoutdata[1:1182, 1] = collect(values(str))[1][20:1201, 1]
			realoutdata[1183:1201, 1] = collect(values(str))[1][(1201-20+2):1201, 1]
			δf_BF_SFR = δf_positor * (sum(δf_actual[1000:1201, 1]) / sum(δf_positor[1000:1201, 1]))
		elseif signal == 2
			xdata = collect(0:0.05:60)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_positor, δf_actual, δf_samplieddata = simulate(generate_data, particle_filter, 100, 60, 2, 1, 0, 1234)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_ASFR = δf_positor

			str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/data/withoutBESSandWinds/realdata2.mat")
			realoutdata = zeros(1201, 1)
			realoutdata[1:1182, 1] = collect(values(str))[1][20:1201, 1]
			realoutdata[1183:1201, 1] = collect(values(str))[1][(1201-20+2):1201, 1]
			δf_BF_SFR = δf_positor * (sum(δf_actual[1000:1201, 1]) / sum(δf_positor[1000:1201, 1]))
		end
	else
		if signal == 1
			xdata = collect(0:0.05:60)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_positor, δf_actual, δf_samplieddata = simulate(generate_data, particle_filter, 100, 60, 1, 1, 1, 1234)
			δf_ASFR = δf_positor

			str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/data/withBESSandWinds/realdata1.mat")
			realoutdata = zeros(1201, 1)
			realoutdata[1:1182, 1] = collect(values(str))[1][20:1201, 1]
			realoutdata[1183:1201, 1] = collect(values(str))[1][(1201-20+2):1201, 1]
			δf_BF_SFR = δf_positor * (sum(δf_actual[1000:1201, 1]) / sum(δf_positor[1000:1201, 1]))
		elseif signal == 2
			xdata = collect(0:0.05:60)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_positor, δf_actual, δf_samplieddata = simulate(generate_data, particle_filter, 100, 60, 2, 1, 1, 1234)
			# δf_ASFR, δf_different, δp_different = frequencydynamic_ASFR()
			δf_ASFR = δf_positor

			str = matread("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/data/withBESSandWinds/realdata2.mat")
			realoutdata = zeros(1201, 1)
			realoutdata[1:1182, 1] = collect(values(str))[1][20:1201, 1]
			realoutdata[1183:1201, 1] = collect(values(str))[1][(1201-20+2):1201, 1]
			δf_BF_SFR = δf_positor * (sum(δf_actual[1000:1201, 1]) / sum(δf_positor[1000:1201, 1]))
		end
	end
	# * output data
	# * ANCHOR xesix, asfr data, bf-sfr data, sim data, samplied data
	return xdata, (δf_ASFR .- 50) .* 0.5, -δf_BF_SFR .* 0.5, realoutdata .* 0.5, δf_samplieddata .* 0.5
end
