%define name jci-interface
%define version 0.1
%define release 1

Name: %{name}
Summary: JCI interface for OBB
Version: %{version}
Release: %{release}
Source0: %{name}-%{version}.tar.gz
License: MIT
Group: Development/Libraries
BuildRoot: /
Prefix: %{_prefix}
BuildArch: x86_64
Vendor: Johnson
Url: http://github/xxxx/test_pack/

%description
UNKNOWN

%prep
%setup -q

%build
python3 setup.py build

%install
echo "This is buildroot"
echo %{buildroot}
mkdir -p %{buildroot}/opt/%{name}
mkdir -p %{buildroot}/usr/lib/%{name}
cp -r bin %{buildroot}/opt/%{name}
cp bin/jci-interface.service %{buildroot}/usr/lib/%{name}

%clean
rm -rf %{buildroot}/opt/%{name}

%files
%{buildroot}/opt/%{name}
%{buildroot}/usr/lib/%{name}

%changelog
* Wed Apr 6 2022 Khayal Ghosh <khayal.ghosh@jci.com>
-
