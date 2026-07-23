%module openmmReaxFF

%include <std_string.i>
%include <std_vector.i>

%{
#define SWIG_FILE_WITH_INIT
#include "openmm/Force.h"
#include "openmm/Vec3.h"
#include "openmm/internal/windowsExportReaxff.h"
#include "openmm/ReaxffForce.h"
%}

// 1. Ignore compiler-specific export macros
#define OPENMM_EXPORT
#define OPENMM_DEPRECATED
#define OPENMM_EXPORT_REAXFF

// 2. Ignore pure virtual methods so SWIG doesn't think the class is abstract
%ignore OpenMM::Force::createImpl;
%ignore OpenMM::ReaxffForce::createImpl;

// 3. Cross-Module Inheritance
%import(module="openmm") "openmm/Force.h"
%import(module="openmm") "openmm/Vec3.h"

// 4. Tell SWIG that the 'symbol' argument in getParticleParameters is an OUTPUT
// (Assuming your C++ signature looks like: void getParticleParameters(int, int&, std::string&, double&, int&))
%apply std::string& OUTPUT { std::string& symbol };

// 5. Include your API
// SWIG will automatically wrap addAtom perfectly, and getParticleParameters will return 
// the symbol as a normal Python string alongside the other return values.
%include "openmm/ReaxffForce.h"

// 6. Clear the typemap so it doesn't accidentally apply to other functions
%clear std::string& symbol;