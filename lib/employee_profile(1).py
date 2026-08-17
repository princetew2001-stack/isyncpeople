from django.shortcuts import render, redirect, get_object_or_404
from django.http import JsonResponse
from django.views import View
from django.db import connection, transaction
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib import messages
from django.utils import timezone

from HRMS_db.models.employee_profile import (
    EmployeeProfile,
    EmployeeProfileRequest,
)

class EmployeeProfileView(LoginRequiredMixin, View):
    login_url = '/login/'

    def get(self, request):
        pay_code = request.user.username
        employee = None
        is_existing = False
        rejected_request = None
        pending_request = None
        employee_data = {}

        try:
            employee = EmployeeProfile.objects.get(emp_code=pay_code)
            employee_data = self._prepare_employee_data(employee)
            is_existing = True
        except EmployeeProfile.DoesNotExist:

            employee_data = self._fetch_from_legacy_db(pay_code)

        if employee:
            pending_request = EmployeeProfileRequest.objects.filter(
                emp_code=employee.emp_code,
                status='PENDING'
            ).first()

            rejected_request = EmployeeProfileRequest.objects.filter(
                emp_code=employee.emp_code,
                status='REJECTED'
            ).order_by('-created_at').first()

        context = {
            'employee': employee_data,
            'is_existing': is_existing,
            'pending_request': pending_request,
            'rejected_request': rejected_request,
        }
        if request.GET.get('json') == '1':
            return JsonResponse(context, safe=False)

        return render(request, 'employee_profile.html', context)

    def post(self, request):
        pay_code = request.user.username

        try:
            employee = EmployeeProfile.objects.filter(emp_code=pay_code).first()
            is_new = employee is None

            profile_data = self._extract_form_data(request)

            emp_code = profile_data.get('emp_code', '')
            if not emp_code:
                messages.error(request, 'Employee code is required.')
                return redirect('employee_profile')

            existing_pending = EmployeeProfileRequest.objects.filter(
                emp_code=emp_code,
                status='PENDING'
            ).first()

            if existing_pending:
                messages.warning(request, 'A pending request already exists. Please wait for HR approval.')
                return redirect('employee_profile')

            qualifications = self._extract_qualifications(request)
            skills = self._extract_skills(request)
            experiences = self._extract_experiences(request)
            hobbies = self._extract_hobbies(request)

            files_to_save = self._extract_files(request)
            file_changes = self._detect_file_changes(employee, files_to_save)

            changed_fields = []
            if not is_new:
                changed_fields = self._calculate_changes(employee, profile_data)
                
                if file_changes:
                    changed_fields.extend(file_changes)

                dynamic_changes = self._detect_dynamic_changes(
                    employee, qualifications, skills, experiences, hobbies
                )
                if dynamic_changes:
                    changed_fields.extend(dynamic_changes)

                if not changed_fields:
                    messages.warning(request, 'No changes detected in any fields.')
                    return redirect('employee_profile')

            with transaction.atomic():
                # Create profile request
                profile_request = EmployeeProfileRequest.objects.create(
                    emp_code=emp_code,
                    employee=employee if not is_new else None,
                    request_type='NEW' if is_new else 'UPDATE',
                    status='PENDING',
                    request_data={
                        **profile_data,
                        'qualifications': qualifications,
                        'skills': skills,
                        'experiences': experiences,
                        'hobbies': hobbies,
                    },
                    changed_fields=changed_fields,
                    created_by=request.user,
                    photo=files_to_save.get('photo'),
                    signature=files_to_save.get('signature'),
                    doc_pan=files_to_save.get('doc_pan'),
                    doc_aadhar=files_to_save.get('doc_aadhar'),
                    doc_other=files_to_save.get('doc_other'),
                )

            msg_type = 'New profile' if is_new else 'Profile update'
            messages.success(request, f'{msg_type} submitted for HR approval!')
            return redirect('employee_profile')

        except ValueError as e:
            messages.error(request, f'Validation Error: {str(e)}')
            return redirect('employee_profile')
        except Exception as e:
            messages.error(request, f'Error: {str(e)}')
            import traceback
            traceback.print_exc()
            return redirect('employee_profile')

    def _extract_form_data(self, request):
        return {
            'emp_code': request.POST.get('emp_code', ''),
            'pay_code': request.POST.get('pay_code', ''),
            'emp_name': request.POST.get('emp_name', ''),
            'gender': request.POST.get('gender', ''),
            'department': request.POST.get('department', ''),
            'designation': request.POST.get('designation', ''),
            'doj': request.POST.get('doj', ''),
            'dob': request.POST.get('dob', ''),
            'reporting_manager': request.POST.get('reporting_manager', ''),
            'official_email': request.POST.get('official_email', ''),
            'father_name': request.POST.get('father_name', ''),
            'mother_name': request.POST.get('mother_name', ''),
            'spouse_name': request.POST.get('spouse_name', ''),
            'personal_email': request.POST.get('personal_email', ''),
            'marital_status': request.POST.get('marital_status', ''),
            'marriage_date': request.POST.get('marriage_date', ''),
            'blood_group': request.POST.get('blood_group', ''),
            'uan_no': request.POST.get('uan_no', ''),
            'ip_no': request.POST.get('ip_no', ''),
            'pan_no': request.POST.get('pan_no', ''),
            'aadhar_no': request.POST.get('aadhar_no', '').replace(" ", ""),
            'esi_no': request.POST.get('esi_no', ''),
            'emergency_name': request.POST.get('emergency_name', ''),
            'emergency_relation': request.POST.get('emergency_relation', ''),
            'emergency_mobile': request.POST.get('emergency_mobile', ''),
            'emergency_phone': request.POST.get('emergency_phone', ''),
            'pres_address': request.POST.get('pres_address', ''),
            'pres_city': request.POST.get('pres_city', ''),
            'pres_tehsil': request.POST.get('pres_tehsil', ''),
            'pres_district': request.POST.get('pres_district', ''),
            'pres_state': request.POST.get('pres_state', ''),
            'pres_pin': request.POST.get('pres_pin', ''),
            'pres_country': request.POST.get('pres_country', ''),
            'perm_address': request.POST.get('perm_address', ''),
            'perm_city': request.POST.get('perm_city', ''),
            'perm_tehsil': request.POST.get('perm_tehsil', ''),
            'perm_district': request.POST.get('perm_district', ''),
            'perm_state': request.POST.get('perm_state', ''),
            'perm_pin': request.POST.get('perm_pin', ''),
            'perm_country': request.POST.get('perm_country', ''),
        }

    def _extract_qualifications(self, request):
        qualifications = []
        degrees = request.POST.getlist('edu_degree[]')
        years = request.POST.getlist('edu_year[]')
        specs = request.POST.getlist('edu_spec[]')

        for i, degree in enumerate(degrees):
            if degree and degree.strip():
                year = None
                if i < len(years) and years[i]:
                    try:
                        year = int(years[i])
                    except (ValueError, TypeError):
                        raise ValueError(f'Qualification year must be a valid number. Got: {years[i]}')

                qualifications.append({
                    'degree': degree.strip(),
                    'year': year,
                    'specialization': specs[i].strip() if i < len(specs) else '',
                })
        return qualifications

    def _extract_skills(self, request):
        skills = []
        names = request.POST.getlist('skill_name[]')
        levels = request.POST.getlist('skill_level[]')
        years = request.POST.getlist('skill_year[]')
        comments = request.POST.getlist('skill_comment[]')

        for i, name in enumerate(names):
            if name and name.strip():
                exp_years = None
                if i < len(years) and years[i]:
                    try:
                        exp_years = int(years[i])
                    except (ValueError, TypeError):
                        raise ValueError(f'Skill experience years must be a valid number. Got: {years[i]}')

                skills.append({
                    'name': name.strip(),
                    'level': levels[i].strip() if i < len(levels) else '',
                    'experience_years': exp_years,
                    'comments': comments[i].strip() if i < len(comments) else '',
                })
        return skills

    def _extract_experiences(self, request):
        experiences = []
        employers = request.POST.getlist('exp_employer[]')
        designations = request.POST.getlist('exp_desig[]')
        from_dates = request.POST.getlist('exp_start[]')
        to_dates = request.POST.getlist('exp_end[]')
        ctcs = request.POST.getlist('exp_ctc[]')
        locations = request.POST.getlist('exp_loc[]')

        for i, employer in enumerate(employers):
            if employer and employer.strip():
                experiences.append({
                    'employer': employer.strip(),
                    'designation': designations[i].strip() if i < len(designations) else '',
                    'from_date': from_dates[i] if i < len(from_dates) else None,
                    'to_date': to_dates[i] if i < len(to_dates) else None,
                    'ctc': ctcs[i].strip() if i < len(ctcs) else '',
                    'location': locations[i].strip() if i < len(locations) else '',
                })
        return experiences

    def _extract_hobbies(self, request):
        hobbies = []

        for h in request.POST.getlist('hobby[]'):
            if h and h.strip():
                hobbies.append({
                    'name': h.strip(),
                    'category': 'Hobby'
                })

        for c in request.POST.getlist('cross_func[]'):
            if c and c.strip():
                hobbies.append({
                    'name': c.strip(),
                    'category': 'Cross Function'
                })

        return hobbies

    def _extract_files(self, request):
        files = {}
        file_fields = ['photo', 'signature', 'doc_pan', 'doc_aadhar', 'doc_other']

        for field in file_fields:
            if request.FILES.get(field):
                files[field] = request.FILES.get(field)

        return files

    def _detect_file_changes(self, employee, new_files):
        file_changes = []

        if not employee:
            if new_files:
                file_changes.extend(new_files.keys())
            return file_changes

        file_fields = {
            'photo': employee.photo,
            'signature': employee.signature,
            'doc_pan': employee.doc_pan,
            'doc_aadhar': employee.doc_aadhar,
            'doc_other': employee.doc_other,
        }

        for field_name, current_file in file_fields.items():
            has_current = bool(current_file)
            has_new = field_name in new_files and new_files[field_name] is not None

            if has_current != has_new or (has_new and has_current):
                file_changes.append(f'{field_name}_file')

        return file_changes

    def _detect_dynamic_changes(self, employee, new_qual, new_skills, new_exp, new_hobbies):
        changes = []

        if employee.qualifications != new_qual:
            changes.append('qualifications')

        if employee.skills != new_skills:
            changes.append('skills')

        if employee.experiences != new_exp:
            changes.append('experiences')

        if employee.hobbies != new_hobbies:
            changes.append('hobbies')

        return changes

    def _calculate_changes(self, employee, new_data):
        changed_fields = []

        EDITABLE_FIELDS = [
            'official_email', 'personal_email', 'father_name', 'mother_name',
            'spouse_name', 'marital_status', 'marriage_date', 'blood_group',
            'uan_no', 'ip_no', 'pan_no', 'aadhar_no', 'esi_no',
            'emergency_name', 'emergency_relation', 'emergency_mobile', 'emergency_phone',
            'pres_address', 'pres_city', 'pres_tehsil', 'pres_district',
            'pres_state', 'pres_pin', 'pres_country',
            'perm_address', 'perm_city', 'perm_tehsil', 'perm_district',
            'perm_state', 'perm_pin', 'perm_country'
        ]

        for field in EDITABLE_FIELDS:
            if field in new_data:
                old_value = getattr(employee, field, None)
                new_value = new_data[field]

                # Compare values
                if str(old_value or '').strip() != str(new_value or '').strip():
                    changed_fields.append(field)

        return changed_fields

    def _prepare_employee_data(self, employee):
        
        data = {
            'emp_code': employee.emp_code,
            'pay_code': employee.pay_code,
            'emp_name': employee.emp_name,
            'gender': employee.gender,
            'department': employee.department,
            'designation': employee.designation,
            'doj': employee.doj,
            'dob': employee.dob,
            'reporting_manager': employee.reporting_manager,
            'official_email': employee.official_email,
            'father_name': employee.father_name,
            'mother_name': employee.mother_name,
            'spouse_name': employee.spouse_name,
            'personal_email': employee.personal_email,
            'marital_status': employee.marital_status,
            'marriage_date': employee.marriage_date,
            'blood_group': employee.blood_group,
            'uan_no': employee.uan_no,
            'ip_no': employee.ip_no,
            'pan_no': employee.pan_no,
            'aadhar_no': employee.aadhar_no,
            'esi_no': employee.esi_no,
            'emergency_name': employee.emergency_name,
            'emergency_relation': employee.emergency_relation,
            'emergency_mobile': employee.emergency_mobile,
            'emergency_phone': employee.emergency_phone,
            'pres_address': employee.pres_address,
            'pres_city': employee.pres_city,
            'pres_tehsil': employee.pres_tehsil,
            'pres_district': employee.pres_district,
            'pres_state': employee.pres_state,
            'pres_pin': employee.pres_pin,
            'pres_country': employee.pres_country,
            'perm_address': employee.perm_address,
            'perm_city': employee.perm_city,
            'perm_tehsil': employee.perm_tehsil,
            'perm_district': employee.perm_district,
            'perm_state': employee.perm_state,
            'perm_pin': employee.perm_pin,
            'perm_country': employee.perm_country,
            'qualifications': employee.qualifications,
            'skills': employee.skills,
            'experiences': employee.experiences,
            'hobbies': employee.hobbies,
            'photo': employee.photo.url if employee.photo else '',
            'signature': employee.signature.url if employee.signature else '',
        }
        return data

    def _fetch_from_legacy_db(self, pay_code):
       
        query = """
        SELECT
            e.emp_code,
            e.pay_code,
            e.name AS emp_name,
            e.adh_no AS aadhar_no,
            e.uan AS uan_no,
            e.doj1 AS doj,
            e.email AS official_email,
            e.f_name AS father_name,
            e.padd AS pres_address,
            d.desc1 AS designation,
            dp.desc1 AS department,
            e.w_name AS spouse_name,
            e.m_name AS mother_name,
            e.phone AS emergency_mobile,
            e.dob,
            CASE WHEN e.m_f = 1 THEN 'Male' ELSE 'Female' END AS gender,
            CASE WHEN e.mrd_st = 2 THEN 'Single' ELSE 'Married' END AS marital_status,
            e.b_grp AS blood_group,
            e.add1 AS perm_address,
            e.pan AS pan_no,
            e.esi_no,
            m.full_name AS reporting_manager

        FROM payroll_01_25.dbo.employee e
        INNER JOIN payroll_01_25.dbo.designation d ON e.des_code = d.des_code
        INNER JOIN payroll_01_25.dbo.department dp ON e.dep_code = dp.dep_code
        INNER JOIN is_intellisync_db.dbo.user_master u ON e.pay_code = u.username
        LEFT JOIN is_intellisync_db.dbo.user_master m ON u.reporting_manager_id = m.id
        WHERE e.pay_code = %s
        """

        try:
            with connection.cursor() as cursor:
                cursor.execute(query, [pay_code])
                row = cursor.fetchone()
                if row:
                    columns = [col[0] for col in cursor.description]
                    data = dict(zip(columns, row))

                    # Set defaults for empty fields
                    default_fields = [
                        'personal_email', 'marriage_date',
                        'ip_no', 'emergency_name', 'emergency_relation',
                        'emergency_phone', 'pres_city', 'pres_tehsil',
                        'pres_district', 'pres_state', 'pres_pin',
                        'pres_country', 'perm_city', 'perm_tehsil',
                        'perm_district', 'perm_state', 'perm_pin',
                        'perm_country'
                    ]
                    for field in default_fields:
                        if field not in data:
                            data[field] = ''

                    return data
        except Exception as e:
            print(f"Legacy DB Error: {e}")
            import traceback
            traceback.print_exc()

        return {}
