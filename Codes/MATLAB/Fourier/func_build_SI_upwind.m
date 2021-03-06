%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Title:          SI-upwind matrix functor
%
%   Author:         Michael W. Hackemack
%   Institution:    Texas A&M University
%   Year:           2015
%   
%   Description:    
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Note(s):        
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function E = func_build_SI_upwind(lam, input)
global glob
% Build Phase Matrix
if input.mesh.Dimension == size(lam,2); lam=lam'; end
node_locs = input.dof.NodeLocations;
PV = exp(1i*node_locs*lam);
PM = diag(PV);
% Retrieve terms
ng = input.data.numberEnergyGroups;
ndofs = input.dof.TotalDoFs;
zdofs = (1:ndofs);
g_offset = (1:ng)*ndofs - ndofs;
m2d = input.Quadrature.moment_to_discrete;
d2m = input.Quadrature.discrete_to_moment;
% Retrieve Matrices
L = func_mat_SI_upwind(lam, input);
S0 = input.ScatteringMatrix;
% Build full matrix based on acceleration type
if input.data.AccelType == glob.Accel_WGS_DSA
    % Build Scattering matrix
    S = zeros(ng*ndofs);
    for g=1:ng
        gdofs = zdofs + g_offset(g);
        for gg=1:ng
            ggdofs = zdofs + g_offset(gg);
            S(gdofs,ggdofs) = S0(:,:,g,gg)*PM;
        end
    end
    % Build transport operators
    E = zeros(ndofs*ng);
    for q=1:input.Quadrature.NumberAngularDirections
        E = E + d2m(1,q)*( L{q}\( m2d(1,q)*S ));
    end
elseif input.data.AccelType == glob.Accel_AGS_TG
    % Build scattering matrices
    Sd = zeros(ng*ndofs);
    Su = zeros(ng*ndofs);
    S  = zeros(ng*ndofs);
    for g=1:ng
        gdofs = zdofs + g_offset(g);
        for gg=1:ng
            ggdofs = zdofs + g_offset(gg);
            tS0 = S0(:,:,g,gg)*PM;
            if gg <= g
                Sd(gdofs,ggdofs) = tS0;
            elseif gg > g
                Su(gdofs,ggdofs) = tS0;
            end
            S(gdofs,ggdofs) = tS0;
        end
    end
    % Build tranpsort matrices
    B = zeros(ng*ndofs); C = zeros(ng*ndofs);
    for q=1:input.Quadrature.NumberAngularDirections
        B = B + d2m(1,q)*( L{q}\( m2d(1,q)*Sd ));
        C = C + d2m(1,q)*( L{q}\( m2d(1,q)*Su ));
    end
    E = (eye(ndofs*ng)-B)\C;
elseif input.data.AccelType == glob.Accel_AGS_MTG
    % Build scattering matrices
    Sd = zeros(ng*ndofs);
    Su = zeros(ng*ndofs);
    for g=1:ng
        gdofs = zdofs + g_offset(g);
        for gg=1:ng
            ggdofs = zdofs + g_offset(gg);
            tS0 = S0(:,:,g,gg)*PM;
            if gg < g
                Sd(gdofs,ggdofs) = tS0;
            elseif gg >= g
                Su(gdofs,ggdofs) = tS0;
            end
        end
    end
    Sd = sparse(Sd); Su = sparse(Su);
    % Build tranpsort matrices
    B = zeros(ng*ndofs); C = zeros(ng*ndofs);
    for q=1:input.Quadrature.NumberAngularDirections
        tL = sparse(L{q}\eye(ndofs*ng));
        B = B + d2m(1,q)*( tL*( m2d(1,q)*Sd ));
        C = C + d2m(1,q)*( tL*( m2d(1,q)*Su ));
    end
    E = (eye(ndofs*ng)-B)\C;
end