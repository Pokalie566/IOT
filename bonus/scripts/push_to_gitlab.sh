#!/bin/bash
# creates the public project on the local gitlab and mirrors the app manifests
# into it, so argo cd can clone without credentials

GITLAB_HOST=gitlab.gitlab.svc.cluster.local:8081
PROJECT=adeboose-iot-app
SOURCE=https://github.com/Pokalie566/adeboose-iot-app.git

kubectl config use-context k3d-iot >/dev/null || exit 1

# throwaway token for this local instance, printed so it is never a hidden secret
TOKEN="glpat-$(openssl rand -hex 10)"

# visibility_level 20 is public: argo cd then clones anonymously and we do not
# have to hand it any credentials
kubectl -n gitlab exec deploy/gitlab -- gitlab-rails runner "
  u = User.find_by_username('root')
  unless u.namespace.projects.find_by_path('$PROJECT')
    Projects::CreateService.new(u, name: '$PROJECT', path: '$PROJECT',
      namespace_id: u.namespace_id, visibility_level: 20).execute
  end
  t = u.personal_access_tokens.create!(name: 'bootstrap-$RANDOM',
    scopes: ['api', 'write_repository'], expires_at: 365.days.from_now)
  t.set_token('$TOKEN')
  t.save!
" || exit 1

# pushing from a pod rather than from the host: the in-cluster dns resolves
# gitlab on its own, so no /etc/hosts entry is needed for the pipeline itself
kubectl -n gitlab run gitpush --rm -i --restart=Never --image=alpine/git:latest \
	--command -- sh -c "
	git clone -q $SOURCE /tmp/repo &&
	cd /tmp/repo &&
	git remote add gitlab http://oauth2:$TOKEN@$GITLAB_HOST/root/$PROJECT.git &&
	git push -q gitlab main && echo pushed" || exit 1

echo
echo "project  http://$GITLAB_HOST/root/$PROJECT"
echo "token    $TOKEN"
