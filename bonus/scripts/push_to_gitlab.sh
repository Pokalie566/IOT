#!/bin/bash
# creates the public project on the local gitlab and mirrors the app manifests

GITLAB_HOST=gitlab.gitlab.svc.cluster.local:8081
PROJECT=adeboose-iot-app
SOURCE=https://github.com/Pokalie566/adeboose-iot-app.git

kubectl config use-context k3d-iot >/dev/null || exit 1

TOKEN="glpat-$(openssl rand -hex 10)"

kubectl -n gitlab exec deploy/gitlab -- gitlab-rails runner "
  u = User.find_by_username('root')
  p = u.namespace.projects.find_by_path('$PROJECT')
  p ||= Projects::CreateService.new(u, name: '$PROJECT', path: '$PROJECT',
    namespace_id: u.namespace_id, visibility_level: 20).execute
  p.protected_branches.destroy_all
  ProtectedBranches::CreateService.new(p, u, {name: 'main', allow_force_push: true,
    push_access_levels_attributes: [{access_level: Gitlab::Access::MAINTAINER}],
    merge_access_levels_attributes: [{access_level: Gitlab::Access::MAINTAINER}]}).execute
  t = u.personal_access_tokens.create!(name: 'bootstrap-$RANDOM',
    scopes: ['api', 'write_repository'], expires_at: 365.days.from_now)
  t.set_token('$TOKEN')
  t.save!
" || exit 1

kubectl -n gitlab run gitpush --rm -i --restart=Never --image=alpine/git:latest \
	--command -- sh -c "
	git clone -q $SOURCE /tmp/repo &&
	cd /tmp/repo &&
	git remote add gitlab http://oauth2:$TOKEN@$GITLAB_HOST/root/$PROJECT.git &&
	git push -qf gitlab main && echo pushed" || exit 1

cat <<EOF

project  http://$GITLAB_HOST/root/$PROJECT
token    $TOKEN
EOF
