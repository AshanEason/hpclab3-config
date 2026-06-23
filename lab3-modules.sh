if [ -f /usr/share/lmod/lmod/init/profile ]; then
  . /usr/share/lmod/lmod/init/profile
elif [ -f /etc/profile.d/lmod.sh ]; then
  . /etc/profile.d/lmod.sh
fi

if command -v module >/dev/null 2>&1; then
  module use --append /home/judge/modulefiles >/dev/null 2>&1 || true
fi
