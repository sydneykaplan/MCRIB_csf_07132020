#!/bin/bash
# ============================================================================
# Developing brain Region Annotation With Expectation-Maximization (Draw-EM)
#
# Copyright 2013-2016 Imperial College London
# Copyright 2013-2016 Andreas Schuh
# Copyright 2013-2016 Antonios Makropoulos
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================


[ $# -eq 1 ] || { echo "usage: $(basename "$0") <subject>" 1>&2; exit 1; }
subj=$1

sdir=segmentations-data

corts=`cat $DRAWEMDIR/parameters/cortical.csv`
wmcorts=`cat $DRAWEMDIR/parameters/cortical-wm.csv`
subcorts=`cat $DRAWEMDIR/parameters/subcortical-all.csv`
all=`cat $DRAWEMDIR/parameters/all-labels.csv `


run(){
  echo "$@"
  "$@" || exit 1
}

if [ ! -f $sdir/MADs/$subj-subspace.nii.gz ];then

mkdir -p $sdir/MADs $sdir/cortical $sdir/transformations $sdir/atlas-weights  || exit 1 
for r in ${all};do mkdir -p $sdir/labels/seg$r || exit 1; done
sigma=10000
run mirtk convert-image N4/$subj.nii.gz $sdir/atlas-weights/$subj-normalized.nii.gz -rescale 0 200 -double 


atlases=""
num=0

#for each atlas
for atnum in {01..20};do
atlas="ALBERT_"$atnum
if [ ! -f dofs/$subj-$atlas-n.dof.gz ];then continue;fi

#transform atlas labels
if [ ! -f $sdir/transformations/$subj-$atlas.nii.gz ];then 
ms=$sdir/template/$str/$subj.nii.gz
run mirtk transform-image $DRAWEMDIR/atlases/ALBERTs/segmentations-v2.1/$atlas.nii.gz $sdir/transformations/$subj-$atlas.nii.gz -target N4/$subj.nii.gz -dofin dofs/$subj-$atlas-n.dof.gz -interp NN 
fi

#transform atlas labels
if [ ! -f $sdir/transformations/T2-$subj-$atlas.nii.gz ];then 
ms=$sdir/template/$str/$subj.nii.gz
run mirtk transform-image $DRAWEMDIR/atlases/ALBERTs/T2/$atlas.nii.gz $sdir/transformations/T2-$subj-$atlas.nii.gz -target N4/$subj.nii.gz -dofin dofs/$subj-$atlas-n.dof.gz -interp BSpline 
fi

#weight atlas labels locally
if [ ! -f $sdir/atlas-weights/$subj-$atlas.nii.gz ];then 
run mirtk normalize N4/$subj.nii.gz $sdir/transformations/T2-$subj-$atlas.nii.gz $sdir/atlas-weights/$subj-$atlas-normalized.nii.gz -piecewise 
run mirtk convert-image $sdir/atlas-weights/$subj-$atlas-normalized.nii.gz $sdir/atlas-weights/$subj-$atlas-normalized.nii.gz -rescale 0 200 -double 
# This calculates weights based on a gaussian distance.
run mirtk calculate $sdir/atlas-weights/$subj-normalized.nii.gz -sub $sdir/atlas-weights/$subj-$atlas-normalized.nii.gz -sq -out $sdir/atlas-weights/$subj-$atlas.nii.gz 
run mirtk calculate-filtering $sdir/atlas-weights/$subj-$atlas.nii.gz -kernel 3 -mean $sdir/atlas-weights/$subj-$atlas.nii.gz  
run mirtk calculate $sdir/atlas-weights/$subj-$atlas.nii.gz -mul -27 -div-with-zero $sigma -out $sdir/atlas-weights/$subj-$atlas.nii.gz  
run mirtk calculate $sdir/atlas-weights/$subj-$atlas.nii.gz -exp -out $sdir/atlas-weights/$subj-$atlas.nii.gz  
# smooth the weights
run mirtk calculate-filtering $sdir/atlas-weights/$subj-$atlas.nii.gz -kernel 3 -median $sdir/atlas-weights/$subj-$atlas.nii.gz  
rm -f $sdir/atlas-weights/$subj-$atlas-normalized.nii.gz
fi

atlases="$atlases $atlas"
num=$(($num+1))
done

rm -f $sdir/atlas-weights/$subj-normalized.nii.gz	


#split labels
transformed=""
transformedw=""
for atlas in ${atlases};do 
transformed="$transformed $sdir/transformations/$subj-$atlas.nii.gz";
transformedw="$transformedw $sdir/atlas-weights/$subj-$atlas.nii.gz";
done

splitnum=87
splitstr=""; for r in {1..87};do splitstr=$splitstr" $r"; done
for r in {1..87};do splitstr=$splitstr" $sdir/labels/seg$r/$subj.nii.gz"; done

mirtk split-labels $num $transformed $transformedw  $splitnum $splitstr 



#tissues
tissues="csf gm wm outlier hwm lwm"
for str in ${tissues};do
mkdir -p $sdir/labels/$str || exit 1
done

ln $sdir/labels/seg83/$subj.nii.gz $sdir/labels/csf
ln $sdir/labels/seg84/$subj.nii.gz $sdir/labels/outlier

str=""; for i in ${corts};do str="$str-add $sdir/labels/seg$i/$subj.nii.gz "; done
str=`echo $str| sed -e 's:^\-add ::g'`
run mirtk calculate $str -out $sdir/labels/gm/$subj.nii.gz 

str=""; for i in ${wmcorts};do str="$str-add $sdir/labels/seg$i/$subj.nii.gz "; done
str=`echo $str| sed -e 's:^\-add ::g'`
run mirtk calculate $str -out $sdir/labels/wm/$subj.nii.gz 


if [ -f $sdir/tissue-posteriors/hwm/$subj.nii.gz -a -f $sdir/tissue-posteriors/lwm/$subj.nii.gz ];then
run mirtk calculate $sdir/tissue-posteriors/wm/$subj.nii.gz -add $sdir/tissue-posteriors/hwm/$subj.nii.gz -add $sdir/tissue-posteriors/lwm/$subj.nii.gz -out $sdir/tissue-posteriors/$subj-wmall.nii.gz 
# hwm = wm_a * hwm_t/wm_t
run mirtk calculate $sdir/tissue-posteriors/hwm/$subj.nii.gz -div-with-zero $sdir/tissue-posteriors/$subj-wmall.nii.gz -mul $sdir/labels/wm/$subj.nii.gz -out $sdir/labels/hwm/$subj.nii.gz 
# lwm = wm_a * lwm_t/wm_t
run mirtk calculate $sdir/tissue-posteriors/lwm/$subj.nii.gz -div-with-zero $sdir/tissue-posteriors/$subj-wmall.nii.gz -mul $sdir/labels/wm/$subj.nii.gz -out $sdir/labels/lwm/$subj.nii.gz 
# wm  = wm_a - lwm - hwm
run mirtk calculate $sdir/labels/wm/$subj.nii.gz -sub $sdir/labels/hwm/$subj.nii.gz -sub $sdir/labels/lwm/$subj.nii.gz -out $sdir/labels/wm/$subj.nii.gz 
rm -f $sdir/tissue-posteriors/$subj-wmall.nii.gz	
fi



#create MAD
if [ ! -f $sdir/MADs/$subj.nii.gz ];then 
nn=5
run mirtk calculate-gradients N4/$subj.nii.gz $sdir/MADs/$subj-grad.nii.gz 0 
run mirtk calculate-filtering $sdir/MADs/$subj-grad.nii.gz -kernel $nn -median $sdir/MADs/$subj-cur.nii.gz  
run mirtk calculate $sdir/MADs/$subj-grad.nii.gz -sub $sdir/MADs/$subj-cur.nii.gz -abs -out $sdir/MADs/$subj-cur.nii.gz 
run mirtk calculate-filtering  $sdir/MADs/$subj-cur.nii.gz -kernel $nn -median $sdir/MADs/$subj-cur.nii.gz  
run mirtk calculate $sdir/MADs/$subj-grad.nii.gz -div-with-zero $sdir/MADs/$subj-cur.nii.gz -div-with-zero 1.4826 -sq -mul 0.5 -add 1 -log -out $sdir/MADs/$subj-cur.nii.gz 
run mirtk calculate N4/$subj.nii.gz -div-with-zero N4/$subj.nii.gz -mul $sdir/MADs/$subj-cur.nii.gz  -add 1 -out $sdir/MADs/$subj-cur.nii.gz 
run mirtk calculate $sdir/MADs/$subj-cur.nii.gz -mul 0 -add 1 -div-with-zero $sdir/MADs/$subj-cur.nii.gz -out $sdir/MADs/$subj.nii.gz 
rm -f $sdir/MADs/$subj-cur.nii.gz
fi

#create posterior penalty
str=""; for i in ${subcorts};do str="$str-add $sdir/labels/seg$i/$subj.nii.gz "; done
str=`echo $str| sed -e 's:^\-add ::g'`
run mirtk calculate $str -div-with-zero 100 -mul $sdir/MADs/$subj.nii.gz -out $sdir/MADs/$subj-subspace.nii.gz 

fi
