package com.codegym.jira.bugtracking.tree;

import com.codegym.jira.bugtracking.ObjectType;
import com.fasterxml.jackson.annotation.JsonProperty;
import org.springframework.lang.NonNull;

import java.util.LinkedList;
import java.util.Collections;
import java.util.List;

public record TreeNode(@NonNull String code, @NonNull Long id, @NonNull ObjectType nodeType,
                       List<TreeNode> subNodes) implements ITreeNode<NodeTo, TreeNode> {
    public TreeNode(NodeTo node) {
        this(node.getCode(), node.getId(), node.getType(), new LinkedList<>());
    }

    //----------- properties for tree constructing ----------

    @JsonProperty
    public String getKey() {
        return nodeType.name() + "-" + id;
    }

    //if node is task there is nothing to load - return all subtasks, else return empty list to enable children lazy loading
    @JsonProperty
    public List<TreeNode> getChildren() {
        if (nodeType == ObjectType.TASK) {
            return subNodes;
        }
        return Collections.emptyList();
    }

    @JsonProperty
    public String getTitle() {
        return code;
    }

    @JsonProperty
    public boolean isLazy() {
        return nodeType != ObjectType.TASK;
    }
}
