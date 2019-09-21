#!/usr/bin/python

# Voltage list for the UBBL07 battery pack
# This has to be in ascending order
volt_map=[3047,3080,3115,3144,3168,3190,3214,3242,3269,3293,3317,3339,3362,3384
,3406,3426,3441,3453,3462,3468,3474,3481,3489,3499,3510,3522,3534,3543,3552,3560
,3567,3574,3580,3586,3590,3594,3598,3602,3606,3610,3614,3617,3620,3624,3627,3630
,3634,3637,3641,3644,3648,3651,3655,3659,3664,3669,3673,3678,3683,3690,3696,3703
,3710,3719,3728,3738,3749,3760,3770,3781,3791,3801,3811,3822,3833,3843,3854,3865
,3875,3886,3898,3909,3921,3933,3945,3957,3969,3982,3994,4007,4020,4032,4046,4059
,4073,4087,4102,4120,9999]

# percentage list for the UBBL07 battery pack.
# Each value is the battery percentage of the 
# corresponding value in volt_map.
percent_map=[0,0,0,1,1,1,1,1,2,2,2,3,3,3,4,5,6,7,8,9,10,12,13,14,15,16,17,18,20
,21,22,23,24,25,27,28,29,30,31,32,33,35,36,37,38,39,40,42,43,44,45,46,47,48,50,51
,52,53,54,55,57,58,59,60,61,62,63,65,66,67,68,69,70,72,73,74,75,76,77,78,80,81,82
,83,84,85,86,88,89,90,91,92,93,95,96,97,98,99,100]

elecValues={'batt_imp':0.08}

def getElecParams():
    elecValues['mV'] = int(open('/sys/class/hwmon/hwmon1/device/in12_input','r').read().rstrip())
    elecValues['mA'] = int(open('/sys/class/hwmon/hwmon1/device/in2_input','r').read().rstrip())-1250
    # elecValues['charging'] = int(open('/sys/class/hwmon/hwmon1/device/in11_input','r').read().rstrip())

def getBattCharge():
    getElecParams()
    bat_mV = float(elecValues['mV']) - float(elecValues['mA']) * (0.1 + elecValues['batt_imp'])
    if bat_mV > 0:
        for i, volt in enumerate(volt_map):
            if volt > bat_mV:
                break;
        batPercent = percent_map[i];
        return batPercent
    else:
        return "error"

if __name__ == "__main__":
    print getBattCharge()
