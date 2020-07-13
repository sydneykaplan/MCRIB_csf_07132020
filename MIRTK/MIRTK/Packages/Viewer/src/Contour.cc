/*=========================================================================

  Library   : Image Registration Toolkit (IRTK)
  Module    : $Id$
  Copyright : Imperial College, Department of Computing
              Visual Information Processing (VIP), 2008 onwards
  Date      : $Date$
  Version   : $Revision$
  Changes   : $Author$

=========================================================================*/

#include <mirtk/Contour.h>

Contour::Contour()
{
  _updateAllPoints=1;
}

void Contour::Add(Point p)
{
  if (_pointSets.size()==0) {
    AddPointSet();
  }
  _pointSets[_pointSets.size()-1].Add(p);
  _updateAllPoints=1;
}

void Contour::AddPointSet()
{
  PointSet *pset = new PointSet;
  _pointSets.push_back(*pset);

}

void Contour::AddNewSet(Point p)
{
  AddPointSet();
  this->Add(p);
}

void Contour::DeleteLastSet()
{

  if (_pointSets.size()>0)_pointSets.pop_back();
  _updateAllPoints=1;
}

int Contour::IsEmpty()
{
  return (_pointSets.size() == 0);
}

int Contour::Size()
{
  if (_pointSets.size() == 0) return 0;
  else {
    int size=0;
    for (unsigned int i=0; i<_pointSets.size(); i++) {
      size+=_pointSets[i].Size();
    }
    return size;
  }
}

void Contour::Clear()
{
  _pointSets.clear();
  _updateAllPoints=1;
}
int Contour::IsInside(double x, double y)
{
  if (_updateAllPoints) {
    AllPoints();
    _updateAllPoints=0;
  }
  return _allPoints.IsInside(x,y);
}

Point& Contour::operator()(int j)
{
  int size=0, i=0;
  while ((size+_pointSets[i].Size()) <=j) {
    size+=_pointSets[i].Size();
    i++;
  }
  return _pointSets[i](j-size);
}


void Contour::AllPoints()
{
  _allPoints.Clear();
  for (unsigned int i=0; i<_pointSets.size(); i++) {
    _allPoints.Add(_pointSets[i]);
  }
}

void Contour::Print()
{
  cerr<<"Contour:" <<endl;
  for (int i=0; i<Size();i++) {
    cerr <<"Point " <<i<<": "<<this->operator()(i)._x << " "<<this->operator()(i)._y << " "<<this->operator()(i)._z <<endl;
  }
}
